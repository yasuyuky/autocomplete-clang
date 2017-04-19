{Point} = require 'atom'

clangSourceScopeDictionary = {
  'source.cpp'    : 'c++' ,
  'source.c'      : 'c' ,
  'source.objc'   : 'objective-c' ,
  'source.objcpp' : 'objective-c++' ,

  # For backward-compatibility with versions of Atom < 0.166
  'source.c++'    : 'c++' ,
  'source.objc++' : 'objective-c++' ,
}

module.exports =
  getFirstCursorSourceScopeLang: (editor) ->
    scopes = @getFirstCursorScopes editor
    return @getSourceScopeLang scopes

  getFirstCursorScopes: (editor) ->
    if editor.getCursors
      firstPosition = editor.getCursors()[0].getBufferPosition()
      scopeDescriptor = editor.scopeDescriptorForBufferPosition(firstPosition)
      scopes = scopeDescriptor.getScopesArray()
    else
      scopes = []

  getSourceScopeLang: (scopes, scopeDictionary=clangSourceScopeDictionary) ->
    lang = null
    for scope in scopes
      if scope of scopeDictionary
        return scopeDictionary[scope]

  prefixAtPosition: (editor, bufferPosition) ->
    regex = /\w+$/
    line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])
    line.match(regex)?[0] or ''

  nearestSymbolPosition: (editor, bufferPosition) ->
    regex = /(\W+)\w*$/
    line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])
    matches = line.match(regex)
    if matches
      symbol = matches[1]
      symbolColumn = matches[0].indexOf(symbol) + symbol.length + (line.length - matches[0].length)
      [new Point(bufferPosition.row, symbolColumn),symbol[-1..]]
    else
      [bufferPosition,'']
