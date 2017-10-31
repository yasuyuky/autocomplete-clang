{CompositeDisposable,Disposable,Selection,File} = require 'atom'
path = require 'path'
util = require './util'
{makeBufferedClangProcess}  = require './clang-args-builder'
{buildGoDeclarationCommandArgs,buildEmitPchCommandArgs} = require './clang-args-builder'
LocationSelectList = require './location-select-view.coffee'

ClangProvider = null
defaultPrecompiled = require './defaultPrecompiled'

module.exports =
  config:
    clangCommand:
      type: 'string'
      default: 'clang'
    includePaths:
      type: 'array'
      default: ['.']
      items:
        type: 'string'
    pchFilePrefix:
      type: 'string'
      default: '.stdafx'
    ignoreClangErrors:
      type: 'boolean'
      default: true
    includeDocumentation:
      type: 'boolean'
      default: true
    includeSystemHeadersDocumentation:
      type: 'boolean'
      default: false
      description:
        "**WARNING**: if there are any PCHs compiled without this option,"+
        "you will have to delete them and generate them again"
    includeNonDoxygenCommentsAsDocumentation:
      type: 'boolean'
      default: false
    "std c++":
      type: 'string'
      default: "c++11"
    "std c":
      type: 'string'
      default: "c99"
    "preCompiledHeaders c++":
      type: 'array'
      default: defaultPrecompiled.cpp
      item:
        type: 'string'
    "preCompiledHeaders c":
      type: 'array'
      default: defaultPrecompiled.c
      items:
        type: 'string'
    "preCompiledHeaders objective-c":
      type: 'array'
      default: defaultPrecompiled.objc
      items:
        type: 'string'
    "preCompiledHeaders objective-c++":
      type: 'array'
      default: defaultPrecompiled.objcpp
      items:
        type: 'string'

  deactivationDisposables: null

  activate: (state) ->
    @deactivationDisposables = new CompositeDisposable
    @deactivationDisposables.add atom.commands.add 'atom-text-editor:not([mini])',
      'autocomplete-clang:emit-pch': =>
        @emitPch atom.workspace.getActiveTextEditor()
    @deactivationDisposables.add atom.commands.add 'atom-text-editor:not([mini])',
      'autocomplete-clang:go-declaration': (e)=>
        @goDeclaration atom.workspace.getActiveTextEditor(),e

  goDeclaration: (editor,e)->
    lang = util.getFirstCursorSourceScopeLang editor
    unless lang
      e.abortKeyBinding()
      return
    editor.selectWordsContainingCursors()
    term = editor.getSelectedText()
    args = buildGoDeclarationCommandArgs editor, lang, term
    callback = (code, outputs, errors, resolve) =>
      console.log "GoDecl err\n", errors
      resolve(@handleGoDeclarationResult editor, {output:outputs, term:term}, code)
    makeBufferedClangProcess editor, args, callback, editor.getText()

  emitPch: (editor)->
    lang = util.getFirstCursorSourceScopeLang editor
    unless lang
      atom.notifications.addError "autocomplete-clang:emit-pch\nError: Incompatible Language"
      return
    headers = atom.config.get "autocomplete-clang.preCompiledHeaders #{lang}"
    headersInput = ("#include <#{h}>" for h in headers).join "\n"
    args = buildEmitPchCommandArgs editor, lang
    callback = (code, outputs, errors, resolve) =>
      console.log "-emit-pch out\n", outputs
      console.log "-emit-pch err\n", errors
      resolve(@handleEmitPchResult code)
    makeBufferedClangProcess editor, args, callback, headersInput

  handleGoDeclarationResult: (editor, result, returnCode)->
    if returnCode is not 0
      return unless atom.config.get "autocomplete-clang.ignoreClangErrors"
    places = @parseAstDump result.output, result.term
    if places.length is 1
      @goToLocation editor, places.pop()
    else if places.length > 1
      list = new LocationSelectList(editor, @goToLocation)
      list.setItems(places)

  goToLocation: (editor, [file,line,col]) ->
    if file is '<stdin>'
      return editor.setCursorBufferPosition [line-1,col-1]
    file = path.join editor.getDirectoryPath(), file if file.startsWith(".")
    f = new File file
    f.exists().then (result) ->
      atom.workspace.open file, {initialLine:line-1, initialColumn:col-1} if result

  parseAstDump: (aststring, term)->
    candidates = aststring.split '\n\n'
    places = []
    for candidate in candidates
      match = candidate.match ///^Dumping\s(?:[A-Za-z_]*::)*?#{term}:///
      if match isnt null
        lines = candidate.split '\n'
        continue if lines.length < 2
        declTerms = lines[1].split ' '
        [_,_,declRangeStr,_,posStr,...] = declTerms
        while not declRangeStr.match /<(.*):([0-9]+):([0-9]+),/
          break if declTerms.length < 5
          declTerms = declTerms[2..]
          [_,_,declRangeStr,_,posStr,...] = declTerms
        if declRangeStr.match /<(.*):([0-9]+):([0-9]+),/
          [_,file,line,col] = declRangeStr.match /<(.*):([0-9]+):([0-9]+),/
          positions = posStr.match /(line|col):([0-9]+)(?::([0-9]+))?/
          if positions
            if positions[1] is 'line'
              [line,col] = [positions[2], positions[3]]
            else
              col = positions[2]
            places.push [file,(Number line),(Number col)]
    return places

  handleEmitPchResult: (code)->
    unless code
      atom.notifications.addSuccess "Emiting precompiled header has successfully finished"
      return
    atom.notifications.addError "Emiting precompiled header exit with #{code}\n"+
      "See console for detailed error message"

  deactivate: ->
    @deactivationDisposables.dispose()

  provide: ->
    ClangProvider ?= require('./clang-provider')
    new ClangProvider()
