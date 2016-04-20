{CompositeDisposable,Disposable,BufferedProcess,Selection,File} = require 'atom'
util = require './util'
{spawn} = require 'child_process'
path = require 'path'
{existsSync} = require 'fs'
ClangFlags = require 'clang-flags'

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
      'autocomplete-clang:go-declaration': (e)=> @goDeclaration atom.workspace.getActiveTextEditor(),e

  goDeclaration: (editor,e)->
    lang = util.getFirstCursorSourceScopeLang editor
    unless lang
      e.abortKeyBinding()
      return
    command = atom.config.get "autocomplete-clang.clangCommand"
    editor.selectWordsContainingCursors();
    term = editor.getSelectedText()
    args = @buildGoDeclarationCommandArgs(editor,lang,term)
    options =
      cwd: path.dirname(editor.getPath())
      input: editor.getText()
    new Promise (resolve) =>
      allOutput = []
      stdout = (output) => allOutput.push(output)
      stderr = (output) => console.log output
      exit = (code) =>
        resolve(@handleGoDeclarationResult(editor, {output:allOutput.join("\n"),term:term}, code))
      bufferedProcess = new BufferedProcess({command, args, options, stdout, stderr, exit})
      bufferedProcess.process.stdin.setEncoding = 'utf-8';
      bufferedProcess.process.stdin.write(editor.getText())
      bufferedProcess.process.stdin.end()

  emitPch: (editor)->
    lang = util.getFirstCursorSourceScopeLang editor
    unless lang
      alert "autocomplete-clang:emit-pch\nError: Incompatible Language"
      return
    clang_command = atom.config.get "autocomplete-clang.clangCommand"
    args = @buildEmitPchCommandArgs editor,lang
    emit_process = spawn clang_command,args
    emit_process.on "exit", (code) => @handleEmitPchResult code
    emit_process.stdout.on 'data', (data)-> console.log "out:\n"+data.toString()
    emit_process.stderr.on 'data', (data)-> console.log "err:\n"+data.toString()
    headers = atom.config.get "autocomplete-clang.preCompiledHeaders #{lang}"
    headersInput = ("#include <#{h}>" for h in headers).join "\n"
    emit_process.stdin.write headersInput
    emit_process.stdin.end()

  buildGoDeclarationCommandArgs: (editor,language,term)->
    std = atom.config.get "autocomplete-clang.std #{language}"
    currentDir = path.dirname(editor.getPath())
    pchFilePrefix = atom.config.get "autocomplete-clang.pchFilePrefix"
    pchFile = [pchFilePrefix, language, "pch"].join '.'
    pchPath = path.join(currentDir, pchFile)

    args = ["-fsyntax-only"]
    args.push "-x#{language}"
    args.push "-std=#{std}" if std
    args.push "-Xclang", "-ast-dump"
    args.push "-Xclang", "-ast-dump-filter"
    args.push "-Xclang", "#{term}"
    args.push("-include-pch", pchPath) if existsSync(pchPath)
    args.push "-I#{i}" for i in atom.config.get "autocomplete-clang.includePaths"
    args.push "-I#{currentDir}"

    try
      clangflags = ClangFlags.getClangFlags(editor.getPath())
      args = args.concat clangflags if clangflags
    catch error
      console.log error

    args.push "-"
    args

  buildEmitPchCommandArgs: (editor,lang)->
    dir = path.dirname editor.getPath()
    pch_file_prefix = atom.config.get "autocomplete-clang.pchFilePrefix"
    file = [pch_file_prefix, lang, "pch"].join '.'
    pch = path.join dir,file
    std = atom.config.get "autocomplete-clang.std #{lang}"
    args = ["-x#{lang}-header", "-Xclang", '-emit-pch', '-o', pch]
    args = args.concat ["-std=#{std}"] if std
    include_paths = atom.config.get "autocomplete-clang.includePaths"
    args = args.concat ("-I#{i}" for i in include_paths)
    args = args.concat ["-"]
    return args

  handleGoDeclarationResult: (editor, result, returnCode)->
    if returnCode is not 0
      return unless atom.config.get "autocomplete-clang.ignoreClangErrors"
    places = @parseAstDump result['output'], result['term']
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
        [_,_,_,_,declRangeStr,_,posStr,...] = declTerms if declRangeStr is "prev"
        [file,line,col] = declRangeStr[1..-2].split ':'
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
      alert "Emiting precompiled header has successfully finished"
      return
    alert "Emiting precompiled header exit with #{code}\n"+
      "See console for detailed error message"

  deactivate: ->
    @deactivationDisposables.dispose()
    console.log "autocomplete-clang deactivated"

  provide: ->
    ClangProvider ?= require('./clang-provider')
    new ClangProvider()
