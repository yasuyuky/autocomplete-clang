path = require 'path'
{existsSync} = require 'fs'
ClangFlags = require 'clang-flags'

module.exports =

  buildCodeCompletionArgs: (editor, row, column, language) ->
    {std, filePath, currentDir, pchPath} = getCommonArgs editor,language
    args = []
    args.push "-fsyntax-only"
    args.push "-x#{language}"
    args.push "-Xclang", "-code-completion-macros"
    args.push "-Xclang", "-code-completion-at=-:#{row + 1}:#{column + 1}"
    args.push("-include-pch", pchPath) if existsSync(pchPath)
    addCommonArgs args, std, currentDir, pchPath, filePath

  buildGoDeclarationCommandArgs: (editor, language, term)->
    {std, filePath, currentDir, pchPath} = getCommonArgs editor,language
    args = []
    args.push "-fsyntax-only"
    args.push "-x#{language}"
    args.push "-Xclang", "-ast-dump"
    args.push "-Xclang", "-ast-dump-filter"
    args.push "-Xclang", "#{term}"
    args.push("-include-pch", pchPath) if existsSync(pchPath)
    addCommonArgs args, std, currentDir, pchPath, filePath

  buildEmitPchCommandArgs: (editor, language)->
    {std, filePath, currentDir, pchPath} = getCommonArgs editor,language
    args = []
    args.push "-x#{language}-header"
    args.push "-Xclang", "-emit-pch", "-o", pchPath
    addCommonArgs args, std, currentDir, pchPath, filePath

getCommonArgs = (editor, language)->
  pchFilePrefix = atom.config.get "autocomplete-clang.pchFilePrefix"
  pchFile = [pchFilePrefix, language, "pch"].join '.'
  filePath = editor.getPath()
  currentDir = path.dirname filePath
  {
    std: (atom.config.get "autocomplete-clang.std #{language}"),
    filePath: filePath,
    currentDir: currentDir,
    pchPath: (path.join currentDir, pchFile)
  }

addCommonArgs = (args, std, currentDir, pchPath, filePath)->
  args.push "-std=#{std}" if std
  args.push "-I#{i}" for i in atom.config.get "autocomplete-clang.includePaths"
  args.push "-I#{currentDir}"
  args = addDocumentationArgs args
  args = addClangFlags args, filePath
  args.push "-"
  args

addClangFlags = (args, filePath)->
  try
    clangflags = ClangFlags.getClangFlags(filePath)
    args = args.concat clangflags if clangflags
  catch error
    console.log "clang-flags error:", error
  args

addDocumentationArgs = (args)->
  if atom.config.get "autocomplete-clang.includeDocumentation"
    args.push "-Xclang", "-code-completion-brief-comments"
    if atom.config.get "autocomplete-clang.includeNonDoxygenCommentsAsDocumentation"
      args.push "-fparse-all-comments"
    if atom.config.get "autocomplete-clang.includeSystemHeadersDocumentation"
      args.push "-fretain-comments-from-system-headers"
  args
