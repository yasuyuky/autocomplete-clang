# autocomplete-plus provider code from https://github.com/benogle/autocomplete-clang
# Copyright (c) 2015 Ben Ogle under MIT license
# Clang related code from https://github.com/yasuyuky/autocomplete-clang

{Point, Range, BufferedProcess, CompositeDisposable} = require 'atom'
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

  convertCompletionLine: (line) ->
    contentRe = /^COMPLETION: (.*)/
    match = line.match contentRe
    return unless match?

    [line, content] = match
    basicInfoRe = /^(.*?) : (.*)/
    match = content.match basicInfoRe
    return {text: content} unless match?

    [content, basicInfo, completionAndComment] = match
    commentRe = /(?: : (.*))?$/
    [completion, comment] = completionAndComment.split commentRe
    returnTypeRe = /^\[#(.*?)#\]/
    returnType = completion.match(returnTypeRe)?[1]
    constMemFuncRe = /\[# const#\]$/
    isConstMemFunc = constMemFuncRe.test completion
    infoTagsRe = /\[#(.*?)#\]/g
    completion = completion.replace infoTagsRe, ''
    argumentsRe = /<#(.*?)#>/g
    index = 0
    completion = completion.replace argumentsRe, (match, arg) ->
      index++
      "${#{index}:#{arg}}"

    suggestion = {}
    suggestion.leftLabel = returnType if returnType?
    if index > 0
      suggestion.snippet = completion
    else
      suggestion.text = completion
    if isConstMemFunc
      suggestion.displayText = completion + ' const'
    suggestion.description = comment if comment?
    suggestion

  handleCompletionResult: (result,returnCode) ->
    if returnCode is not 0
      return unless atom.config.get "autocomplete-clang.ignoreClangErrors"
    outputLines = result.trim().split '\n'
    completions = (@convertCompletionLine(s) for s in outputLines)
    (completion for completion in completions when completion?)

  buildClangArgs: (editor, row, column, language) ->
    std = atom.config.get "autocomplete-clang.std #{language}"
    currentDir = path.dirname(editor.getPath())
    pchFilePrefix = atom.config.get "autocomplete-clang.pchFilePrefix"
    pchFile = [pchFilePrefix, language, "pch"].join '.'
    pchPath = path.join(currentDir, pchFile)

    args = ["-fsyntax-only"]
    args.push "-x#{language}"
    args.push "-std=#{std}" if std
    args.push "-Xclang", "-code-completion-macros"
    args.push "-Xclang", "-code-completion-at=-:#{row + 1}:#{column + 1}"
    args.push("-include-pch", pchPath) if existsSync(pchPath)
    args.push "-I#{i}" for i in atom.config.get "autocomplete-clang.includePaths"
    args.push "-I#{currentDir}"

    if atom.config.get "autocomplete-clang.includeDocumentation"
      args.push "-Xclang", "-code-completion-brief-comments"
      if atom.config.get "autocomplete-clang.includeNonDoxygenCommentsAsDocumentation"
        args.push "-fparse-all-comments"

    try
      clangflags = ClangFlags.getClangFlags(editor.getPath())
      args = args.concat clangflags if clangflags
    catch error
      console.log error

    args.push "-"
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
