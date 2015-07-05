# Some of the clang related code from https://github.com/yasuyuky/autocomplete-clang
# Copyright (c) 2014 Yasuyuki YAMADA under MIT license

{Point, Range, BufferedProcess, TextEditor, CompositeDisposable} = require 'atom'
path = require 'path'
{existsSync} = require 'fs'

module.exports =
class ClangProvider
  selector: '.source.cpp, .source.c, .source.objc, .source.objcpp'
  inclusionPriority: 1
  excludeLowerPriority: true

  clangCommand: "clang"
  includePaths: [".", ".."]

  scopeSource:
    'source.cpp': 'c++'
    'source.c': 'c'
    'source.objc': 'objective-c'
    'source.objcpp': 'objective-c++'

  getSuggestions: ({editor, scopeDescriptor, bufferPosition}) ->
    language = LanguageUtil.getSourceScopeLang(@scopeSource, scopeDescriptor.getScopesArray())
    prefix = LanguageUtil.prefixAtPosition(editor, bufferPosition)
    symbolPosition = LanguageUtil.nearestSymbolPosition(editor, bufferPosition) ? bufferPosition

    # console.log "'#{prefix}'", bufferPosition, language
    if language?
      @codeCompletionAt(editor, symbolPosition.row, symbolPosition.column, language).then (suggestions) =>
        @filterForPrefix(suggestions, prefix)

  codeCompletionAt: (editor, row, column, language) ->
    command = @clangCommand
    args = @buildClangArgs(editor, row, column, language)
    options =
      cwd: path.dirname(editor.getPath())
      input: editor.getText()

    new Promise (resolve) =>
      allOutput = []
      stdout = (output) => allOutput.push(output)
      stderr = (output) => console.log output
      exit = (output) => resolve(@handleCompletionResult(allOutput.join('\n')))
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

  lineRe: /COMPLETION: (.+) : (.+)$/
  returnTypeRe: /\[#([^#]+)#\]/ig
  argumentRe: /\<#([^#]+)#\>/ig
  convertCompletionLine: (s) ->
    match = s.match(@lineRe)
    if match?
      [line, completion, pattern] = match
      returnType = null
      patternNoType = pattern.replace @returnTypeRe, (match, type) ->
        returnType = type
        ''
      index = 0
      replacement = patternNoType.replace @argumentRe, (match, arg) ->
        index++
        "${#{index}:#{arg}}"

      suggestion = {label: "returns #{returnType}"}
      if index > 0
        suggestion.snippet = replacement
      else
        suggestion.text = replacement
      suggestion

  handleCompletionResult: (result) ->
    outputLines = result.trim().split '\n'
    completions = (@convertCompletionLine(s) for s, i in outputLines when i < 1000)
    (completion for completion in completions when completion?)

  buildClangArgs: (editor, row, column, language)->
    # pch = [(atom.config.get "autocomplete-clang.pchFilePrefix"), language, "pch"].join '.'
    args = ["-fsyntax-only", "-x#{language}", "-Xclang"]
    location = "-:#{row + 1}:#{column + 1}"
    args.push("-code-completion-at=#{location}")

    pchPath = path.join(path.dirname(editor.getPath()), 'test.pch')
    args = args.concat ["-include-pch", pchPath] if existsSync pchPath
    # std = atom.config.get "autocomplete-clang.std.#{language}"
    # args = args.concat ["-std=#{std}"] if std
    args = args.concat("-I#{i}" for i in @includePaths)
    args.push("-")
    args





LanguageUtil =
  getSourceScopeLang: (scopeSource, scopesArray) ->
    for scope in scopesArray
      return scopeSource[scope] if scope of scopeSource
    null

  prefixAtPosition: (editor, bufferPosition) ->
    regex = /[\w0-9_-]+$/ # whatever your prefix regex might be
    line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])
    line.match(regex)?[0] or ''

  nearestSymbolPosition: (editor, bufferPosition) ->
    methodCall = "\\[([\\w_-]+) (?:[\\w_-]+)?"
    propertyAccess = "([\\w_-]+)\\.(?:[\\w_-]+)?"
    regex = new RegExp("(?:#{propertyAccess})|(?:#{methodCall})$", 'i')

    line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])
    matches = line.match(regex)
    if matches
      symbol = matches[1] ? matches[2]
      symbolColumn = matches[0].indexOf(symbol) + symbol.length + (line.length - matches[0].length)
      new Point(bufferPosition.row, symbolColumn)
