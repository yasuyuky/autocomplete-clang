util = require './util'

_ = require 'underscore-plus'
{spawn} = require 'child_process'
path = require 'path'
{existsSync} = require 'fs'
snippets = require 'snippets/lib/snippets'
{$,$$,Range,SelectListView} = require 'atom'

ClangFlags = require 'clang-flags'

module.exports =
class AutocompleteClangView extends SelectListView
  clangOutput: ""
  wordRegex: /\w+/g

  initialize: (@editorView) ->
    super
    @addClass('autocomplete popover-list')
    {@editor} = @editorView
    @handleEvents()
    @setCurrentBuffer(@editor.getBuffer())

  getFilterKey: ->
    'word'

  viewForItem: ({label}) ->
    $$ ->
      @li =>
        @span label[..50]

  handleEvents: ->
    @list.on 'mousewheel', (event) -> event.stopPropagation()

    @editorView.on 'editor:path-changed', => @setCurrentBuffer(@editor.getBuffer())
    @editorView.command 'autocomplete-clang:toggle', => @toggle()
    @editorView.command 'autocomplete:next', => @selectNextItemView()
    @editorView.command 'autocomplete:previous', => @selectPreviousItemView()
    if atom.config.get 'autocomplete-clang.enableAutoToggle'
      @editor.getBuffer().on "changed", (e) => @handleChanged(e) if e.newText

    @filterEditorView.getModel().on 'will-insert-text', ({cancel, text}) =>
      unless text.match(@wordRegex)
        @confirmSelection()
        @editor.insertText(text)
        cancel()

  setCurrentBuffer: (@currentBuffer) ->

  selectItemView: (item) ->
    super
    if match = @getSelectedItem()
      @replaceSelectedTextWithMatch(match)

  selectNextItemView: ->
    super
    false

  selectPreviousItemView: ->
    super
    false

  handleChanged: (event)->
    return if @hasParent()
    pos = @editor.getCursorBufferPosition()
    for c in atom.config.get "autocomplete-clang.autoToggleKeys"
      if c[-1..] == event.newText and c == @getBufferTextInColumnDelta(pos, -1*c.length)
        @editor.commitTransaction()
        @editor.beginTransaction()
        @toggle()

  getBufferTextInColumnDelta: (point,columnDelta)->
    r = Range.fromPointWithDelta(point,0,columnDelta)
    return @editor.getBuffer().getTextInRange r

  toggle: ->
    if @hasParent()
      @cancel()
    else
      @attach()

  attach: ->
    @editor.beginTransaction()

    @aboveCursor = false
    @originalSelectionBufferRanges = @editor.getSelections().map (selection) ->
      selection.getBufferRange()
    @originalCursorPosition = @editor.getCursorScreenPosition()

    @buildWordList()

  buildWordList: ->
    firstCursorPosition = @editor.getCursors()[0].getBufferPosition()
    lang = util.getFirstCursorSourceScopeLang @editor
    return @cancel unless lang
    @codeCompletionAt firstCursorPosition.row, firstCursorPosition.column, lang

  codeCompletionAt: (row, column, lang) ->
    args = @buildClangArgs row, column, lang
    @clangOutput = ""
    clang = spawn (atom.config.get "autocomplete-clang.clangCommand"), args, {cwd: path.dirname @editor.getPath()}
    clang.stdout.on 'data', (data) => @handleCompletionOutput data
    clang.stderr.on 'data', (data) => @handleClangError data
    clang.on 'exit', (code) => @handleCompletionClose code
    clang.stdin.write @editor.getText()
    clang.stdin.end()

  buildClangArgs: (row, column, lang)->
    pch = [(atom.config.get "autocomplete-clang.pchFilePrefix"), lang, "pch"].join '.'
    args = ["-fsyntax-only", "-x#{lang}", "-Xclang"]
    location = (["-",row+1,column+1].join ':')
    args = args.concat ["-code-completion-at=#{location}"]
    pchPath = path.join (path.dirname @editor.getPath()), pch
    args = args.concat ["-include-pch", pch] if existsSync pchPath
    std = atom.config.get "autocomplete-clang.std.#{lang}"
    args = args.concat ["-std=#{std}"] if std
    args = args.concat ("-I#{i}" for i in atom.config.get "autocomplete-clang.includePaths")
    try
      clangflags = ClangFlags.getClangFlags(atom.workspace.getActiveTextEditor().getPath())
      args = args.concat clanflags if clangflags
    catch error
      console.log error
    args = args.concat ["-"]

  convertClangCompletion: (s) ->
    s = s[12..]
    l = s.match /^[^ ]+\s:\s/
    s = s.replace /^[^ ]+\s:\s/, ""
    s = s.replace /\[#(.*?)#\]/g, ""
    i = 0
    snipet = s.replace /<#(.*?)#>|{#(.*?)#}/g, (match,p1,p2) ->
      ++i
      "${#{i}:#{p1 or p2}}"
    slabel = s.replace /<#(.*?)#>/g, (match,p1) -> "#{p1}"
    return {word:snipet, label:slabel} if s

  handleCompletionOutput: (data) ->
    @clangOutput += data.toString()

  handleCompletionClose: (code) ->
    if code
      console.log "Unexpected return code of clang command:",code
      return @cancel()
    completions = (@convertClangCompletion(s) for s in @clangOutput.trim().split '\n')
    items = _.remove completions, undefined
    @setItems items
    if items.length == 1
      @Selection()
    else
      @editorView.appendToLinesView(this)
      @setPosition()
      @focusFilterEditor()

  handleClangError: (data)->
    console.log data.toString()

  cancelled: ->
    super
    unless @editor.isDestroyed()
      @editor.abortTransaction()
      @editor.setSelectedBufferRanges(@originalSelectionBufferRanges)
      @editorView.focus()

  replaceSelectedTextWithMatch: (match) ->
    newSelectedBufferRanges = []

    @editor.getSelections().forEach (selection, i) =>
      startPosition = selection.getBufferRange().start
      selection.deleteSelectedText()
      cursorPosition = @editor.getCursors()[i].getBufferPosition()
      newSelectedBufferRanges.push([startPosition, [startPosition.row, startPosition.column + match.word.length]])

    @editor.insertText(match.word)
    @editor.setSelectedBufferRanges(newSelectedBufferRanges)

  setPosition: ->
    {left, top} = @editorView.pixelPositionForScreenPosition(@originalCursorPosition)
    height = @outerHeight()
    width = @outerWidth()
    potentialTop = top + @editorView.lineHeight
    potentialBottom = potentialTop - @editorView.scrollTop() + height
    parentWidth = @parent().width()

    left = parentWidth - width if left + width > parentWidth

    if @aboveCursor or potentialBottom > @editorView.outerHeight()
      @aboveCursor = true
      @css(left: left, top: top - height, bottom: 'inherit')
    else
      @css(left: left, top: potentialTop, bottom: 'inherit')

  confirmed: (match) ->
    return unless match
    @cancel()
    @editor.getCursors().forEach (cursor) ->
      snippets.insert(match.word, @editor, cursor)
