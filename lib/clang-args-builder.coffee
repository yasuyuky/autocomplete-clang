{BufferedProcess} = require 'atom'
path = require 'path'
fs = require 'fs'
tmp = require 'tmp'
ClangFlags = require 'clang-flags'

module.exports =

  makeBufferedClangProcess: (editor, args, callback, input)->
    new Promise (resolve) ->
      command = atom.config.get "autocomplete-clang.clangCommand"
      options = cwd: path.dirname editor.getPath()
      [outputs, errors] = [[], []]
      stdout = (data)-> outputs.push data
      stderr = (data)-> errors.push data
      argsCountThreshold = atom.config.get("autocomplete-clang.argsCountThreshold")
      if (args.join(" ")).length > (argsCountThreshold or 7000)
        [args, filePath] = makeFileBasedArgs args, editor
        exit = (code)->
          fs.unlinkSync filePath
          callback code, (outputs.join '\n'), (errors.join '\n'), resolve
      else
        exit = (code)-> callback code, (outputs.join '\n'), (errors.join '\n'), resolve
      bufferedProcess = new BufferedProcess({command, args, options, stdout, stderr, exit})
      bufferedProcess.process.stdin.setEncoding = 'utf-8'
      bufferedProcess.process.stdin.write input
      bufferedProcess.process.stdin.end()

  buildCodeCompletionArgs: (editor, row, column, language) ->
    {std, filePath, currentDir, pchPath} = getCommonArgs editor,language
    args = []
    args.push "-fsyntax-only"
    args.push "-x#{language}"
    args.push "-Xclang", "-code-completion-macros"
    args.push "-Xclang", "-code-completion-at=-:#{row + 1}:#{column + 1}"
    args.push("-include-pch", pchPath) if fs.existsSync(pchPath)
    addCommonArgs args, std, currentDir, pchPath, filePath

  buildGoDeclarationCommandArgs: (editor, language, term)->
    {std, filePath, currentDir, pchPath} = getCommonArgs editor,language
    args = []
    args.push "-fsyntax-only"
    args.push "-x#{language}"
    args.push "-Xclang", "-ast-dump"
    args.push "-Xclang", "-ast-dump-filter"
    args.push "-Xclang", "#{term}"
    args.push("-include-pch", pchPath) if fs.existsSync(pchPath)
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

makeFileBasedArgs = (args, editor)->
  args = args.join('\n')
  args = args.replace /\\/g, "\\\\"
  args = args.replace /\ /g, "\\\ "
  filePath = tmp.fileSync().name
  fs.writeFile filePath, args, (error) ->
    console.error("Error writing file", error) if error
  args = ['@' + filePath]
  [args, filePath]
