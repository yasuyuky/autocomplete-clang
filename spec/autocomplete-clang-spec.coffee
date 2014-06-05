{WorkspaceView} = require 'atom'
AutocompleteClang = require '../lib/autocomplete-clang'

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.

describe "AutocompleteClang", ->
  activationPromise = null

  beforeEach ->
    atom.workspaceView = new WorkspaceView
    activationPromise = atom.packages.activatePackage('autocomplete-clang')

  describe "when the autocomplete-clang:toggle event is triggered", ->
    it "attaches and then detaches the view", ->
      expect(atom.workspaceView.find('.autocomplete-clang')).not.toExist()

      # This is an activation event, triggering it will cause the package to be
      # activated.
      atom.workspaceView.trigger 'autocomplete-clang:toggle'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(atom.workspaceView.find('.autocomplete-clang')).toExist()
        atom.workspaceView.trigger 'autocomplete-clang:toggle'
        expect(atom.workspaceView.find('.autocomplete-clang')).not.toExist()
