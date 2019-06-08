{CompositeDisposable} = require 'atom'
pchEmitter = require './pch-emitter'
jumper = require './jumper'

ClangProvider = null
defaultPrecompiled = require './default-precompiled'

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
      default: "c++14"
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

  emitPch: (editor) -> pchEmitter.emitPch editor

  goDeclaration: (editor, e) -> jumper.goDeclaration editor, e

  deactivate: ->
    @deactivationDisposables.dispose()

  provide: ->
    ClangProvider ?= require('./clang-provider')
    new ClangProvider()
