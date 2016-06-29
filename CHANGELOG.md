## 0.9.4
* Avoid excluding autocomplete-plus suggestions
* Improve performance

## 0.9.3
* Fix missing require

## 0.9.2
* Fix buildGoDeclarationCommandArgs

## 0.9.1
* Fix missing dependency

## 0.9.0
* Add "autocomplete-clang:go-declaration" command (#92)
* Fix many bugs and improve output (#96, #99, #100)

## 0.8.9
* Add check for autocomplete-plus minimumWordLength
* Add current directory to include path

## 0.8.8
* Add support for showing brief documentation comments
* Fix loading std config

## 0.8.7
* Remove the word 'returns' from right label
* Improve completions to include completions without patterns

## 0.8.6
* Add -code-completion-macros argument to enable macro completion

## 0.8.5
* Relax the limit of clang outputs

## 0.8.4
* Reintroduce config settings

## 0.8.3
* Improve behavior with semicolon

## 0.8.2
* Reintroduce "symbol position" with better symbol regex
* Use rightLabel instead of label

## 0.8.1
* Stop using symbol position to better completions

## 0.8.0
* Start working with [autocomplete-plus](https://github.com/atom/autocomplete-plus)!
  Most of provider code from https://github.com/benogle/autocomplete-clang
  Copyright (c) 2015 Ben Ogle under MIT license.

## 0.7.0
* Stop using deprecated transaction API (inline preview feature was disabled)

## 0.6.9
* Update menu cson
* Update package.json

## 0.6.8
* Update config settings / solve #44

## 0.6.7
* Fix emitPch command

## 0.6.6
* Fix crash with insertion of punctuation / solve #39

## 0.6.5
* Replace old API (scopesForBufferPosition)

## 0.6.4
* Fix undefined function in emit-pch

## 0.6.3
* Update package.json (again) to point out specific version of clang-flags

## 0.6.2
* Update package.json to fix the installation problem / solve #35, #34

## 0.6.1
* Merge pull-request #29 to Use tag instead of deprecated class in keymap

## 0.6
* Update APIs (except APIs for transaction)

## 0.5.4
* Merge pull-request #27 to fixed clang-flags repo.

## 0.5.3
* Merge pull-request #23 to handle new scope names for C++, Objective-C++
* Update package.json to use forked version of "clang-flags"

## 0.5.2
* Fix problem that insert completion into wrong position

## 0.5.1
* Fix problem with multiple cursors

## 0.5
* Add "Igonore Clang Error" option
* Add error handling for the case that clang is not installed

## 0.4
* Improved snippets behavior

## 0.3.3
* Fix invalid input when auto toggle is disabled

## 0.3.2
* Fix problem with new rule of transaction (works with Atom 0.147.0)

## 0.3.1
* Fix problem with objc

## 0.3.0
* Support latest version of atom

## 0.2.0
* Support .clang_complete

## 0.1.0 - First Release
* Initial Release
