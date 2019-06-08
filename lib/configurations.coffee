defaultPrecompiled = require './default-precompiled'

module.exports =
  clangCommand:
    type: 'string'
    default: 'clang'
  includePaths:
    type: 'array'
    default: ['.']
    items:
      type: 'string'
  pchFilePrefix:
    type: 'string'
    default: '.stdafx'
  ignoreClangErrors:
    type: 'boolean'
    default: true
  includeDocumentation:
    type: 'boolean'
    default: true
  includeSystemHeadersDocumentation:
    type: 'boolean'
    default: false
    description:
      "**WARNING**: if there are any PCHs compiled without this option,"+
      "you will have to delete them and generate them again"
  includeNonDoxygenCommentsAsDocumentation:
    type: 'boolean'
    default: false
  "std c++":
    type: 'string'
    default: "c++14"
  "std c":
    type: 'string'
    default: "c99"
  "preCompiledHeaders c++":
    type: 'array'
    default: defaultPrecompiled.cpp
    item:
      type: 'string'
  "preCompiledHeaders c":
    type: 'array'
    default: defaultPrecompiled.c
    items:
      type: 'string'
  "preCompiledHeaders objective-c":
    type: 'array'
    default: defaultPrecompiled.objc
    items:
      type: 'string'
  "preCompiledHeaders objective-c++":
    type: 'array'
    default: defaultPrecompiled.objcpp
    items:
      type: 'string'
