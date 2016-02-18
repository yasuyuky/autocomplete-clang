util = require './util'
{spawn} = require 'child_process'
path = require 'path'
{CompositeDisposable,Disposable,BufferedProcess,Selection,File} = require 'atom'
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
      'autocomplete-clang:go-declaration': => @goDeclaration atom.workspace.getActiveTextEditor()


  goDeclaration: (editor)->
    lang = util.getFirstCursorSourceScopeLang editor
    unless lang
      alert "autocomplete-clang:go-declaration\nError: Incompatible Language"
      return
    command = atom.config.get "autocomplete-clang.clangCommand"
    editor.selectWordsContainingCursors();
    term = editor.getSelectedText()
    p = editor.getDirectoryPath()
    args = @buildGoDeclarationCommandArgs(editor,lang,term)
    options =
      cwd: path.dirname(editor.getPath())
      input: editor.getText()
    new Promise (resolve) =>
      allOutput = []
      stdout = (output) => allOutput.push(output)
      stderr = (output) => console.log output
      exit = (code) =>
        resolve(@handleGoDeclarationResult({output:allOutput.join("\n"),term:term, path:p }, code))
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

  buildGoDeclarationCommandArgs: (editor,lang,term)->
    std = atom.config.get "autocomplete-clang.std #{lang}"
    args = ["-x#{lang}-header", "-fsyntax-only", "-Xclang", "-ast-dump", "-Xclang", "-ast-dump-filter","-Xclang" ]
    args = args.concat ["#{term}"]
    args = args.concat ["-std=#{std}"] if std
    include_paths = atom.config.get("autocomplete-clang.includePaths")
    args = args.concat ("-I#{i}" for i in include_paths)
    args = args.concat ["-"]
    return args

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

  handleGoDeclarationResult: (result,returnCode)->
    if returnCode is not 0
        return unless atom.config.get "autocomplete-clang.ignoreClangErrors"
    outputLines = result['output']
    t = result['term']
    baseregex = ///\w+Decl[^<]+<(?!col:)(..[^:,]+):?(\d+):?\d+?.*?col:(\d+).*?\s#{t}\s///
    classregex = ///.*CXXRecordDecl[^<]+<([^:,]+):(\d+):(\d+).*?#{t}\ definition.*///
    m = outputLines.match(baseregex)
    if m and m.length > 1 and m[1].trim() is "line"
      m = outputLines.match(classregex)
    if m == null
      return
    filematch = m[1] if m and m.length > 1
    linematch = m[2] if m and m.length > 2
    colmatch  = m[3] if m and m.length > 3
    p = result['path'] + '/'
    if filematch.startsWith("./")
      filematch = p + filematch
    f = new File filematch
    f.exists().then (result) ->
      if result
        atom.workspace.open(filematch, {initialLine:Number(linematch)-1, initialColumn:Number(colmatch)-1})

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
