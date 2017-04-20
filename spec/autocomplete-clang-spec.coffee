os = require 'os'
fs = require 'fs'
path = require 'path'
tmp = require 'tmp'

describe "C++ autocompletions", ->
  [editor, provider] = []
  workdir = path.dirname __filename

  getCompletions = ->
    cursor = editor.getLastCursor()
    start = cursor.getBeginningOfCurrentWordBufferPosition()
    end = cursor.getBufferPosition()
    prefix = editor.getTextInRange([start, end])
    request =
      editor: editor
      bufferPosition: end
      scopeDescriptor: cursor.getScopeDescriptor()
      prefix: prefix
    provider.getSuggestions(request)

  beforeEach ->
    waitsForPromise -> atom.packages.activatePackage('language-c')
    waitsForPromise -> atom.packages.activatePackage('autocomplete-clang')
    runs ->
      provider = atom.packages.getActivePackage('autocomplete-clang').mainModule.provide()
    waitsForPromise ->
      atom.workspace.open(path.join(workdir, tmp.tmpNameSync(template: 'XXXXXX.cpp')))
    runs ->
      editor = atom.workspace.getActiveTextEditor()

  it "autcompletes methods of a string", ->
    editor.setText """
    #include<string>

    int main() {
      std::string s;
      s.
      return 0;
    }
    """
    editor.setCursorBufferPosition([4, 4])
    waitsForPromise ->
      completions = getCompletions()
      completions.then (cs)->
        expect(cs.length).toBeGreaterThan(100)

  it "emits precompiled headers", ->
    waitsForPromise ->
      atom.packages.getActivePackage('autocomplete-clang').mainModule.emitPch editor
    runs ->
      pchFile = [atom.config.get("autocomplete-clang.pchFilePrefix"),'c++','pch'].join '.'
      expect(fs.statSync(path.join workdir, pchFile)).not.toBe(undefined)

  it "moves cursor to declaration", ->
    editor.setText """
    #include<string>

    int main() {
      std::string s;
      s;
      return 0;
    }
    """
    editor.setCursorBufferPosition([4, 3])
    waitsForPromise ->
      atom.packages.getActivePackage('autocomplete-clang').mainModule.goDeclaration editor
    runs ->
      expect(editor.getCursorBufferPosition().row).toEqual(3)

  it "autcompletes with args in the file", ->
    atom.config.set "autocomplete-clang.argsCountThreshold", 1
    editor.setText """
    #include<string>

    int main() {
      std::string s;
      s.
      return 0;
    }
    """
    editor.setCursorBufferPosition([4, 4])
    waitsForPromise ->
      completions = getCompletions()
      completions.then (cs)->
        expect(cs.length).toBeGreaterThan(100)
