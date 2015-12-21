# autocomplete-plus provider code from https://github.com/benogle/autocomplete-clang
# Copyright (c) 2015 Ben Ogle under MIT license
# Clang related code from https://github.com/yasuyuky/autocomplete-clang

{Point, Range, BufferedProcess, TextEditor, CompositeDisposable} = require 'atom'
path = require 'path'
{existsSync} = require 'fs'
ClangFlags = require 'clang-flags'

module.exports =
class ClangProvider
  selector: '.source.cpp, .source.c, .source.objc, .source.objcpp'
  inclusionPriority: 1
  excludeLowerPriority: true

  scopeSource:
    'source.cpp': 'c++'
    'source.c': 'c'
    'source.objc': 'objective-c'
    'source.objcpp': 'objective-c++'

  getSuggestions: ({editor, scopeDescriptor, bufferPosition}) ->
    language = LanguageUtil.getSourceScopeLang(@scopeSource, scopeDescriptor.getScopesArray())
    prefix = LanguageUtil.prefixAtPosition(editor, bufferPosition)
    [symbolPosition,lastSymbol] = LanguageUtil.nearestSymbolPosition(editor, bufferPosition)
    minimumWordLength = atom.config.get('autocomplete-plus.minimumWordLength')

    if minimumWordLength? and prefix.length < minimumWordLength
      regex = /(?:\.|->|::)\s*\w*$/
      line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])
      return unless regex.test(line)

    if language?
      @codeCompletionAt(editor, symbolPosition.row, symbolPosition.column, language).then (suggestions) =>
        @filterForPrefix(suggestions, prefix)

  codeCompletionAt: (editor, row, column, language) ->
    command = atom.config.get "autocomplete-clang.clangCommand"
    args = @buildClangArgs(editor, row, column, language)
    options =
      cwd: path.dirname(editor.getPath())
      input: editor.getText()

    new Promise (resolve) =>
      allOutput = []
      stdout = (output) => allOutput.push(output)
      stderr = (output) => console.log output
      exit = (code) => resolve(@handleCompletionResult(allOutput.join('\n'),code))
      bufferedProcess = new BufferedProcess({command, args, options, stdout, stderr, exit})
      bufferedProcess.process.stdin.setEncoding = 'utf-8';
      bufferedProcess.process.stdin.write(editor.getText())
      bufferedProcess.process.stdin.end()

  filterForPrefix: (suggestions, prefix) ->
    res = []
    for suggestion in suggestions
      if (suggestion.snippet or suggestion.text).startsWith(prefix)
        suggestion.replacementPrefix = prefix
        res.push(suggestion)
    res

  lineRe: /COMPLETION: ([^:]+)(?: : (.+))?$/
  returnTypeRe: /\[#([^#]+)#\]/ig
  argumentRe: /\<#([^#]+)#\>/ig
  commentSplitRe: /(?: : (.+))?$/
  convertCompletionLine: (s) ->
    match = s.match(@lineRe)
    if match?
      [line, completion, pattern] = match
      unless pattern?
        return {snippet:completion,text:completion}
      [patternNoComment, briefComment] = pattern.split @commentSplitRe
      returnType = null
      patternNoType = patternNoComment.replace @returnTypeRe, (match, type) ->
        returnType = type
        ''
      index = 0
      replacement = patternNoType.replace @argumentRe, (match, arg) ->
        index++
        "${#{index}:#{arg}}"

      suggestion = {}
      suggestion.rightLabel = returnType if returnType?
      if index > 0
        suggestion.snippet = replacement
      else
        suggestion.text = replacement
      suggestion.description = briefComment if briefComment?
      suggestion

  handleCompletionResult: (result,returnCode) ->
    if returnCode is not 0
      return unless atom.config.get "autocomplete-clang.ignoreClangErrors"
    outputLines = result.trim().split '\n'
    completions = (@convertCompletionLine(s) for s in outputLines)
    (completion for completion in completions when completion?)

  buildClangArgs: (editor, row, column, language)->
    pch = [(atom.config.get "autocomplete-clang.pchFilePrefix"), language, "pch"].join '.'
    args = ["-fsyntax-only", "-x#{language}", "-Xclang", "-code-completion-macros", "-Xclang"]
    location = "-:#{row + 1}:#{column + 1}"
    args.push("-code-completion-at=#{location}")

    if atom.config.get("autocomplete-clang.includeDocumentation")?
      args = args.concat ["-Xclang", "-code-completion-brief-comments"]
      args.push("-fparse-all-comments") if atom.config.get("autocomplete-clang.includeNonDoxygenCommentsAsDocumentation")

    currentDir=path.dirname(editor.getPath())
    pchPath = path.join(currentDir, 'test.pch')
    args = args.concat ["-include-pch", pchPath] if existsSync pchPath
    std = atom.config.get "autocomplete-clang.std #{language}"
    args = args.concat ["-std=#{std}"] if std
    args = args.concat ("-I#{i}" for i in atom.config.get "autocomplete-clang.includePaths")
    args.push("-I#{currentDir}")
    try
      clangflags = ClangFlags.getClangFlags(editor.getPath())
      args = args.concat clangflags if clangflags
    catch error
      console.log error
    args.push("-")
    args

LanguageUtil =
  getSourceScopeLang: (scopeSource, scopesArray) ->
    for scope in scopesArray
      return scopeSource[scope] if scope of scopeSource
    null

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
