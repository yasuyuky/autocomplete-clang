AutocompleteClangView = require './autocomplete-clang-view'
util = require './util'
{spawn} = require 'child_process'
path = require 'path'
_ = require 'underscore-plus'

module.exports =
  configDefaults:
    clangCommand: "clang"
    includePaths: ["."]
    pchFilePrefix: ".stdafx"
    enableAutoToggle: true
    autoToggleKeys: [".","#","::","->"]
    appendDefaultOutputOfAutocomplete: false
    std:
      "c++": "c++03"
      "c": "c99"
    preCompiledHeaders: {
      "c++":[
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
      ],
      "c": [
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
      ],
      "objc": [],
      "objc++": [],
    }

  autocompleteClangViews: []

  activate: (state) ->
    @editorSubscription = atom.workspaceView.eachEditorView (editor) =>
      if editor.attached and not editor.mini
        autocompleteClangView = new AutocompleteClangView(editor)
        editor.on 'editor:will-be-removed', =>
          autocompleteClangView.remove() unless autocompleteClangView.hasParent()
          _.remove @autocompleteClangViews, autocompleteClangView
        @autocompleteClangViews.push(autocompleteClangView)
        editor.command "autocomplete-clang:emit-pch", => @emitPch editor.getEditor()

  emitPch: (editor)->
    lang = util.getFirstCursorSourceScopeLang editor
    unless lang
      alert "autocomplete-clang:emit-pch\nError: Incompatible Language"
      return
    args = @buildEmitPchCommandArgs editor,lang
    emit_process = spawn (atom.config.get "autocomplete-clang.clangCommand"),args
    emit_process.on "exit", (code) => @handleEmitPchResult code
    emit_process.stdout.on 'data', (data) => console.log "out:\n"+data.toString()
    emit_process.stderr.on 'data', (data) => console.log "err:\n"+data.toString()
    headers = atom.config.get "autocomplete-clang.preCompiledHeaders.#{lang}"
    headersInput = ("#include <#{h}>" for h in headers).join "\n"
    emit_process.stdin.write headersInput
    emit_process.stdin.end()

  buildEmitPchCommandArgs: (editor,lang)->
    dir = path.dirname editor.getPath()
    file = [(atom.config.get "autocomplete-clang.pchFilePrefix"), lang, "pch"].join '.'
    pch = path.join dir,file
    std = atom.config.get "autocomplete-clang.std.#{lang}"
    args = ['-cc1', "-x#{lang}-header", '-emit-pch', '-o', pch]
    args = args.concat ["-std=#{std}"] if std
    args = args.concat ("-I#{i}" for i in atom.config.get "autocomplete-clang.includePaths")
    args = args.concat ["-"]
    return args

  handleEmitPchResult: (code)->
    unless code
      alert "Emiting precompiled header has successfully finished"
      return
    alert "Emiting precompiled header exit with #{code}\nSee console for detailed error message"

  deactivate: ->
    for view in @autocompleteClangViews
      view.destroy()
