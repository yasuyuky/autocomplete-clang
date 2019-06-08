{CompositeDisposable} = require 'atom'
pchEmitter = require './pch-emitter'
jumper = require './jumper'
configurations = require './configurations'

ClangProvider = null

module.exports =
  config: configurations

  deactivationDisposables: null

  activate: (state) ->
    @deactivationDisposables = new CompositeDisposable
    @deactivationDisposables.add atom.commands.add 'atom-text-editor:not([mini])',
      'autocomplete-clang:emit-pch': =>
        @emitPch atom.workspace.getActiveTextEditor()
    @deactivationDisposables.add atom.commands.add 'atom-text-editor:not([mini])',
      'autocomplete-clang:go-declaration': (e)=>
        @goDeclaration atom.workspace.getActiveTextEditor(), e

  emitPch: (editor) -> pchEmitter.emitPch editor

  goDeclaration: (editor, e) -> jumper.goDeclaration editor, e

  deactivate: ->
    @deactivationDisposables.dispose()

  provide: ->
    ClangProvider ?= require('./clang-provider')
    new ClangProvider()
