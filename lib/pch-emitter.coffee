commonUtil = require './common-util'
{makeBufferedClangProcess}  = require './clang-args-builder'
{buildEmitPchCommandArgs} = require './clang-args-builder'

module.exports =
  emitPch: (editor)->
    lang = commonUtil.getFirstCursorSourceScopeLang editor
    unless lang
      atom.notifications.addError "autocomplete-clang:emit-pch\nError: Incompatible Language"
      return
    headers = atom.config.get "autocomplete-clang.preCompiledHeaders #{lang}"
    headersInput = ("#include <#{h}>" for h in headers).join "\n"
    args = buildEmitPchCommandArgs editor, lang
    callback = (code, outputs, errors, resolve) =>
      console.log "-emit-pch out\n", outputs
      console.log "-emit-pch err\n", errors
      resolve(@handleEmitPchResult code)
    makeBufferedClangProcess editor, args, callback, headersInput

  handleEmitPchResult: (code)->
    unless code
      atom.notifications.addSuccess "Emiting precompiled header has successfully finished"
      return
    atom.notifications.addError "Emiting precompiled header exit with #{code}\n"+
      "See console for detailed error message"
