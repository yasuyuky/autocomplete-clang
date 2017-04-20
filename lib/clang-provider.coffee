# autocomplete-plus provider code from https://github.com/benogle/autocomplete-clang
# Copyright (c) 2015 Ben Ogle under MIT license
# Clang related code from https://github.com/yasuyuky/autocomplete-clang

{Range, CompositeDisposable} = require 'atom'
path = require 'path'
{makeBufferedClangProcess, buildCodeCompletionArgs} = require './clang-args-builder'
{getSourceScopeLang, prefixAtPosition, nearestSymbolPosition} = require './util'

module.exports =
class ClangProvider
  selector: '.source.cpp, .source.c, .source.objc, .source.objcpp'
  inclusionPriority: 1

  getSuggestions: ({editor, scopeDescriptor, bufferPosition}) ->
    language = getSourceScopeLang scopeDescriptor.getScopesArray()
    prefix = prefixAtPosition(editor, bufferPosition)
    [symbolPosition,lastSymbol] = nearestSymbolPosition(editor, bufferPosition)
    minimumWordLength = atom.config.get('autocomplete-plus.minimumWordLength')

    if minimumWordLength? and prefix.length < minimumWordLength
      regex = /(?:\.|->|::)\s*\w*$/
      line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])
      return unless regex.test(line)

    if language?
      @codeCompletionAt(editor, symbolPosition.row, symbolPosition.column, language, prefix)

  codeCompletionAt: (editor, row, column, language, prefix) ->
    args = buildCodeCompletionArgs editor, row, column, language
    callback = (code, outputs, errors, resolve) =>
      console.log errors
      resolve(@handleCompletionResult(outputs, code, prefix))
    makeBufferedClangProcess editor, args, callback, editor.getText()

  convertCompletionLine: (line, prefix) ->
    contentRe = /^COMPLETION: (.*)/
    [line, content] = line.match contentRe
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
    optionalArgumentsStart = completion.indexOf '{#'
    completion = completion.replace /\{#/g, ''
    completion = completion.replace /#\}/g, ''
    index = 0
    completion = completion.replace argumentsRe, (match, arg, offset) ->
      index++
      if optionalArgumentsStart > 0 and offset > optionalArgumentsStart
        return "${#{index}:optional #{arg}}"
      else
        return "${#{index}:#{arg}}"

    suggestion = {}
    suggestion.leftLabel = returnType if returnType?
    if index > 0
      suggestion.snippet = completion
    else
      suggestion.text = completion
    if isConstMemFunc
      suggestion.displayText = completion + ' const'
    suggestion.description = comment if comment?
    suggestion.replacementPrefix = prefix
    suggestion

  handleCompletionResult: (result, returnCode, prefix) ->
    if returnCode is not 0
      return unless atom.config.get "autocomplete-clang.ignoreClangErrors"
    # Find all completions that match our prefix in ONE regex
    # for performance reasons.
    completionsRe = new RegExp("^COMPLETION: (" + prefix + ".*)$", "mg")
    outputLines = result.match(completionsRe)

    if outputLines?
      return (@convertCompletionLine(line, prefix) for line in outputLines)
    else
      return []
