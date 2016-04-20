# autocomplete-clang package

This package provides completions by [clang](http://clang.llvm.org/)
like [emacs auto-complete-clang.el](https://github.com/brianjcj/auto-complete-clang).

using [autocomplete-plus](https://atom.io/packages/autocomplete-plus)

**for `C`/`C++`/`Objective-C`**

![Screenshot for how autocomplete works](https://raw.githubusercontent.com/yasuyuky/autocomplete-clang/DocumentImage/images/autocomplete-clang.gif)

This package is currently in an experimental state.

## Requirement

- [autocomplete-plus](https://atom.io/packages/autocomplete-plus)
- **[clang](http://clang.llvm.org/)**


## Features

- Providing completions by clang
- Auto toggle
  - default keys `[".","#","::","->"]`
- Using `std` option like `c++11`
- Using precompile headers for clang
- Goto symbol definition in a source file

## Using precompiled headers

It can use precompiled headers for clang. *Optional*

Command for emitting precompiled header is easily access from menu.

### Emitting pch(precompiled header file),

1. Open `C`/`C++`/`Objective-C` source file on editor buffer.
2. Choose `Packages` -> `Autocomplete Clang` -> `Emit Precompiled Header`
3. Then package automatically detect emitted pch file.

![Screenshot of emit-pch](https://raw.githubusercontent.com/yasuyuky/autocomplete-clang/DocumentImage/images/autocomplete-clang-emit-pch.png)

### Notice

If you change the `std` option after you emitted the pch, you should emit pch again.

## Settings

### Global

![Screenshot of configuration](https://raw.githubusercontent.com/yasuyuky/autocomplete-clang/DocumentImage/images/autocomplete-clang-settings.png)

### Project

autocomplete-clang will look for a .clang_complete file as used by vim's [clang_complete](https://github.com/Rip-Rip/clang_complete) plugin, by searching up the directory tree. If it finds one, it'll use this to add parameters passed to clang. Use this for adding project-specific defines or include paths. The format is simply one parameter per line, e.g.
```
  -I/opt/qt/5.3/clang_64/lib/QtWebKitWidgets.framework/Versions/5/Headers
  -I/opt/qt/5.3/clang_64/lib/QtMultimedia.framework/Versions/5/Headers
  -DSWIFT_EXPERIMENTAL_FT
```

## Keymaps

### Default keymaps

Also you can customize keymaps by editing ~/.atom/keymap.cson
(choose Open Your Keymap in Atom menu):

```cson
'.workspace':
  'cmd-ctrl-alt-e': 'autocomplete-clang:emit-pch'
  'f3': 'autocomplete-clang:go-declaration'
```

See [basic customization](http://flight-manual.atom.io/using-atom/sections/basic-customization/#_customizing_keybindings) for more details.

## License

MIT (See License file)

## Update problems

    Error message: Module version mismatch.

If you got a such kind of errors after AtomEditor update, Try following commands.

    cd ~/.atom/package/autocomplete-clang/
    rm -rf node_modules && apm install

## Misc

- Motivation of the original author is `C++`,
  So that tests for `C`/`Objective-C` may be not enough.

- Any casual feedbacks to [@yasuyuky](https://twitter.com/yasuyuky) are welcome.
