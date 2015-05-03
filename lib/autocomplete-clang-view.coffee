util = require './util'

_ = require 'underscore-plus'
{spawnSync} = require 'child_process'
path = require 'path'
{existsSync} = require 'fs'
{Range, CompositeDisposable} = require 'atom'
{$, $$, SelectListView}  = require 'atom-space-pen-views'

ClangFlags = require 'clang-flags'

module.exports =
class AutocompleteClangView extends SelectListView
  clangOutput: ""
  wordRegex: /\w+/g

  initialize: (@editor) ->
    super
    @addClass('autocomplete popover-list')
    @handleEvents()
    @setCurrentBuffer(@editor.getBuffer())
    if atom.packages.isPackageLoaded("snippets")
      @snippets = atom.packages.getLoadedPackage("snippets").mainModule

  getFilterKey: ->
    'word'

  viewForItem: ({label}) ->
    $$ ->
      @li =>
        @span label[..50]

  handleEvents: ->
    @list.on 'mousewheel', (event) -> event.stopPropagation()

    @editor.onDidChangePath => @setCurrentBuffer(@editor.getBuffer())

    @filterEditorView.getModel().onWillInsertText ({cancel, text}) =>
      unless text.match(@wordRegex)
        @confirmSelection()
        @editor.insertText text

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

  handleTextInsertion: (event)->
    return if @isVisible()
    pos = @editor.getCursorBufferPosition()
    for c in atom.config.get "autocomplete-clang.autoToggleKeys"
      if c[-1..] == event.text
        if c == @getBufferTextInColumnDelta(pos, -1*c.length)
          @toggle event.text

  getBufferTextInColumnDelta: (point,columnDelta)->
    r = Range.fromPointWithDelta(point,0,columnDelta)
    return @editor.getBuffer().getTextInRange r

  toggle: (prefix) ->
    if @isVisible()
      @cancel()
    else
      @prefix = prefix
      @attach()

  attach: ->
    @aboveCursor = false
    @originalCursorPosition = @editor.getCursorScreenPosition()
    items = @buildWordList()
    if items and items.length
      @editor.beginTransaction()
      @setItems items
      cursorMarker = @editor.getLastCursor().getMarker()
      @overlayDecoration = @editor.decorateMarker(cursorMarker, type: 'overlay', position: 'tail', item: this)

  buildWordList: ->
    firstCursorPosition = @editor.getCursors()[0].getBufferPosition()
    lang = util.getFirstCursorSourceScopeLang @editor
    return unless lang
    @codeCompletionAt firstCursorPosition.row, firstCursorPosition.column, lang

  codeCompletionAt: (row, column, lang) ->
    command = atom.config.get "autocomplete-clang.clangCommand"
    args = @buildClangArgs row, column, lang
    options = {cwd: (path.dirname @editor.getPath()), input: @editor.getText()}
    result = spawnSync command, args, options
    @handleCompletionResult result

  buildClangArgs: (row, column, lang)->
    pch = [(atom.config.get "autocomplete-clang.pchFilePrefix"), lang, "pch"].join '.'
    args = ["-fsyntax-only", "-x#{lang}", "-Xclang"]
    location = (["-",row+1,column+1].join ':')
    args = args.concat ["-code-completion-at=#{location}"]
    pchPath = path.join (path.dirname @editor.getPath()), pch
    args = args.concat ["-include-pch", pch] if existsSync pchPath
    std = atom.config.get "autocomplete-clang.std #{lang}"
    args = args.concat ["-std=#{std}"] if std
    args = args.concat ("-I#{i}" for i in atom.config.get "autocomplete-clang.includePaths")
    try
      clangflags = ClangFlags.getClangFlags(atom.workspace.getActiveTextEditor().getPath())
      args = args.concat clangflags if clangflags
    catch error
      console.log error
    args = args.concat ["-"]

  convertCompletionLine: (s) ->
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

  handleCompletionResult: (result) ->
    if result.error
      console.log result.error
      return
    if result.status
      console.log "Unexpected return code of clang command:", result.status
      console.log result.stderr.toString()
      return unless atom.config.get "autocomplete-clang.ignoreClangErrors"
    outputLines = result.stdout.toString().trim().split '\n'
    completions = (@convertCompletionLine(s) for s in outputLines)
    items = _.remove completions, undefined

  cancelled: ->
    @overlayDecoration?.destroy()
    unless @editor.isDestroyed()
      try
        @editor.abortTransaction() # @editor.revertToCheckpoint(@checkpoint)
        @editor.insertText @prefix if @prefix
        atom.workspace.getActivePane().activate()

  replaceSelectedTextWithMatch: (match) ->
    newSelectedBufferRanges = []

    @editor.getSelections().forEach (selection, i) =>
      startPosition = selection.getBufferRange().start
      selection.deleteSelectedText()
      cursorPosition = @editor.getCursors()[i].getBufferPosition()
      range = [startPosition.row, startPosition.column + match.word.length]
      newSelectedBufferRanges.push([startPosition, range])
    @editor.insertText match.label
    @editor.setSelectedBufferRanges(newSelectedBufferRanges)

  attached: ->
    @focusFilterEditor()
    widestCompletion = parseInt(@css('min-width')) or 0
    @list.find('span').each ->
      widestCompletion = Math.max(widestCompletion, $(this).outerWidth())
    @list.width(widestCompletion)
    @width(@list.outerWidth())

  detached: ->

  confirmed: (match) ->
    return unless match
    @cancel()
    if @snippets
      @editor.getCursors().forEach (cursor) =>
        @snippets.insert match.word,@editor,cursor
    else
      @editor.insertText match.label
