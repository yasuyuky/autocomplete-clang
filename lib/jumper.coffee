{File} = require 'atom'
path = require 'path'
SelectList = require 'atom-select-list'

{getFirstScopes, getScopeLang} = require './common-util'
{spawnClang, buildAstDumpArgs} = require './clang-args-builder'


module.exports =
  goDeclaration: (editor,e)->
    lang = getScopeLang (getFirstScopes editor)
    unless lang
      e.abortKeyBinding()
      return
    editor.selectWordsContainingCursors()
    term = editor.getSelectedText()
    cwd = path.dirname editor.getPath()
    args = buildAstDumpArgs editor, lang, term
    spawnClang cwd, args, editor.getText(), (code, outputs, errors, resolve) =>
      console.log "GoDecl err\n", errors
      resolve(@handleAstDumpResult editor, {output:outputs, term:term}, code)

  handleAstDumpResult: (editor, result, returnCode)->
    if returnCode is not 0
      return unless atom.config.get "autocomplete-clang.ignoreClangErrors"
    places = @parseAstDump result.output, result.term
    if places.length is 1
      @jumpToLocation editor, places.pop()
    else if places.length > 1
      declList = @createDeclList editor, places
      @lastFocusedElement = document.activeElement
      @panel = atom.workspace.addModalPanel item: declList
      declList.focus()

  createDeclList: (editor, places) ->
    new SelectList
      items: places
      elementForItem: (item) ->
        element = document.createElement('li')
        if item[0] is '<stdin>'
          element.innerHTML = "#{item[1]}:#{item[2]}"
        else
          f = path.join(item[0])
          element.innerHTML "#{f}  #{item[1]}:#{item[2]}"
        element
      filterKeyForItem: (item) -> item.label,
      didConfirmSelection: (item) =>
        @hideDeclList()
        @jumpToLocation editor, item
      didCancelSelection: () =>
        @hideDeclList()

  hideDeclList: ()->
    if @panel and @panel.destroy
      @panel.destroy()
    if @lastFocusedElement
      @lastFocusedElement.focus()
      @lastFocusedElement = null

  jumpToLocation: (editor, [file,line,col]) ->
    if file is '<stdin>'
      return editor.setCursorBufferPosition [line-1,col-1]
    file = path.join editor.getDirectoryPath(), file if file.startsWith(".")
    f = new File file
    f.exists().then (result) ->
      atom.workspace.open file, {initialLine:line-1, initialColumn:col-1} if result

  parseAstDump: (aststring, term)->
    candidates = aststring.split '\n\n'
    places = []
    escapedTerm = term.match /[A-Za-z_][A-Za-z0-9_]*/
    return [] if escapedTerm is null
    for candidate in candidates
      match = candidate.match ///^Dumping\s(?:[A-Za-z_]*::)*?#{escapedTerm}:///
      if match isnt null
        lines = candidate.split '\n'
        continue if lines.length < 2
        declTerms = lines[1].split ' '
        [_,_,declRangeStr,_,posStr,...] = declTerms
        while not declRangeStr.match /<(.*):([0-9]+):([0-9]+),/
          break if declTerms.length < 5
          declTerms = declTerms[2..]
          [_,_,declRangeStr,_,posStr,...] = declTerms
        if declRangeStr.match /<(.*):([0-9]+):([0-9]+),/
          [_,file,line,col] = declRangeStr.match /<(.*):([0-9]+):([0-9]+),/
          positions = posStr.match /(line|col):([0-9]+)(?::([0-9]+))?/
          if positions
            if positions[1] is 'line'
              [line,col] = [positions[2], positions[3]]
            else
              col = positions[2]
            places.push [file,(Number line),(Number col)]
    return places
