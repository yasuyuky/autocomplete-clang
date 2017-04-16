describe "C++ autocompletions", ->
  [editor, provider] = []

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
    waitsForPromise -> atom.workspace.open('/tmp/test.cpp')
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
    completions = getCompletions()
    completions.then ->
      expect(completions.length).toBeGreaterThan(100)
