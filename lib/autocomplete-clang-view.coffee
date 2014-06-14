util = require './util'

_ = require 'underscore-plus'
{spawn} = require 'child_process'
path = require 'path'
{existsSync, readFileSync} = require 'fs'
Autocompleteview = require 'autocomplete/lib/autocomplete-view'
snippets = require 'snippets/lib/snippets'
{Range} = require 'atom'
{File, Directory} = require 'pathwatcher'

module.exports =
class AutocompleteClangView extends Autocompleteview
  clangOutput: ""

  handleEvents: ->
    @list.on 'mousewheel', (event) -> event.stopPropagation()

    @editorView.on 'editor:path-changed', => @setCurrentBuffer(@editor.getBuffer())
    @editorView.command 'autocomplete-clang:toggle', => @toggle()
    @editorView.command 'autocomplete:next', => @selectNextItemView()
    @editorView.command 'autocomplete:previous', => @selectPreviousItemView()
    if atom.config.get 'autocomplete-clang.enableAutoToggle'
      @editor.getBuffer().on 'changed', (event) => @handleChanged event

    @filterEditorView.preempt 'textInput', ({originalEvent}) =>
      text = originalEvent.data
      unless text.match(@wordRegex)
        @confirmSelection()
        @editor.insertText(text)
        false

  handleChanged: (event)->
    return if @hasParent()
    for c in atom.config.get "autocomplete-clang.autoToggleKeys"
      if c[-1..] == event.newText[-1..] and (
        c.length == 1 or
        c == @getBufferTextInColumnDelta event.newRange.end, -1*c.length)
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

    return @cancel() unless @allPrefixAndSuffixOfSelectionsMatch()
    @buildWordList()

  buildWordList: ->
    super if atom.config.get("autocomplete-clang.appendDefaultOutputOfAutocomplete")
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
    args = ["-cc1", "-fsyntax-only", "-x#{lang}",
            "-code-completion-at", (["-",row+1,column+1].join ':'),
           ]
    pchPath = path.join (path.dirname @editor.getPath()), pch
    args = args.concat ["-include-pch", pch] if existsSync pchPath
    std = atom.config.get "autocomplete-clang.std.#{lang}"
    args = args.concat ["-std=#{std}"] if std
    args = args.concat ("-I#{i}" for i in atom.config.get "autocomplete-clang.includePaths")
    # If someone already has a .clang_complete from vim configured, use that.
    searchDir = path.dirname @editor.getPath()
    while searchDir.length
        searchFilePath = path.join searchDir, ".clang_complete"
        searchFile = new File(searchFilePath)
        if searchFile.exists()
            contents = ""
            try
                contents = readFileSync(searchFilePath, 'utf8')
            catch error
                console.log "autocomplete-clang couldn't read file " + searchFilePath
                console.log error
            contentsArray = contents.split("\n")
            args = args.concat contentsArray
            args = args.concat ["-working-directory=#{searchDir}"] # All the includes will be relative to the .clang_complete
            break
        thisDir = new Directory(searchDir)
        if thisDir.isRoot()
            break
        searchDir = thisDir.getParent().getPath()
    return args

  convertClangCompletion: (s) ->
    s = s[12..]
    l = s.match /^[^ ]+\s:\s/
    s = s.replace /^[^ ]+\s:\s/, ""
    s = s.replace /\[#(.*?)#\]/g, ""
    i = 0
    s = s.replace /<#(.*?)#>/g, (match,p1) ->
      ++i
      "${#{i}:#{p1}}"
    return {word:s, prefix:'',suffix:'',label:if l then l[0] else s} if s

  handleCompletionOutput: (data) ->
    @clangOutput += data.toString()

  handleCompletionClose: (code) ->
    if code
      console.log "Unexpected return code of clang command:",code
      return @cancel()
    completions = _.remove (@convertClangCompletion(s) for s in @clangOutput.trim().split '\n'), undefined
    matches = if @wordList then @findMatchesForCurrentSelection() else []
    items = completions.concat matches
    @setItems items
    switch items.length
      when 0
        @cancel()
      when 1
        @confirmSelection()
      else
        @editorView.appendToLinesView this
        @setPosition()
        @focusFilterEditor()

  handleClangError: (data)->
    console.log data.toString()

  confirmed: (match) ->
    @editor.getSelections().forEach (selection) -> selection.clear()
    @cancel()
    return unless match
    snippets.insert match.word
