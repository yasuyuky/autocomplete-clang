util = require './util'
{spawn} = require 'child_process'
path = require 'path'
{CompositeDisposable,Disposable} = require 'atom'
ClangProvider = null

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
    enableAutoToggle:
      type: 'boolean'
      default: true
    autoToggleKeys:
      type: 'array'
      default: [".","#","::","->"]
      items:
        type: 'string'
    ignoreClangErrors:
      type: 'boolean'
      default: true
    "std c++":
      type: 'string'
      default: "c++11"
    "std c":
      type: 'string'
      default: "c99"
    "preCompiledHeaders c++":
      type: 'array'
      default: [
        "cassert",
        "cctype",
        "cerrno",
        "cfloat",
        "ciso646",
        "climits",
        "clocale",
        "cmath",
        "csetjmp",
        "csignal",
        "cstdarg",
        "cstddef",
        "cstdio",
        "cstdlib",
        "cstring",
        "ctime",
        "cwchar",
        "cwctype",
        "deque",
        "list",
        "map",
        "queue",
        "set",
        "stack",
        "vector",
        "fstream",
        "iomanip",
        "ios",
        "iosfwd",
        "iostream",
        "istream",
        "ostream",
        "sstream",
        "streambuf",
        "algorithm",
        "bitset",
        "complex",
        "exception",
        "functional",
        "iterator",
        "limits",
        "locale",
        "memory",
        "new",
        "numeric",
        "stdexcept",
        "string",
        "typeinfo",
        "utility",
        "valarray",
      ]
      item:
        type: 'string'
    "preCompiledHeaders c":
      type: 'array'
      default: [
        "assert.h",
        "complex.h",
        "ctype.h",
        "errno.h",
        "fenv.h",
        "float.h",
        "inttypes.h",
        "iso646.h",
        "limits.h",
        "locale.h",
        "math.h",
        "setjmp.h",
        "signal.h",
        "stdalign.h",
        "stdarg.h",
        "stdatomic.h",
        "stdbool.h",
        "stddef.h",
        "stdint.h",
        "stdio.h",
        "stdlib.h",
        "stdnoreturn.h",
        "string.h",
        "tgmath.h",
        "threads.h",
        "time.h",
        "uchar.h",
        "wchar.h",
        "wctype.h",
      ]
      items:
        type: 'string'
    "preCompiledHeaders objective-c":
      type: 'array'
      default: []
      items:
        type: 'string'
    "preCompiledHeaders objective-c++":
      type: 'array'
      default: []
      items:
        type: 'string'

  deactivationDisposables: null

  activate: (state) ->
    @deactivationDisposables = new CompositeDisposable
    @deactivationDisposables.add atom.commands.add 'atom-text-editor:not([mini])',
      'autocomplete-clang:emit-pch': =>
        @emitPch atom.workspace.getActiveTextEditor()

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
