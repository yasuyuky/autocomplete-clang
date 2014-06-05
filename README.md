# autocomplete-clang package

This package provides completions by [clang](http://clang.llvm.org/)
like [emacs auto-complete-clang.el](https://github.com/brianjcj/auto-complete-clang).

**for `C`/`C++`/`Objective-C`**

![Screenshot for how autocomplete works](https://raw.githubusercontent.com/yasuyuky/autocomplete-clang/DocumentImage/images/autocomplete-clang.gif)

This package is currently experimental state.

## Features

- Providing completions by clang
- Auto toggle
  - default keys `[".","#","::","->"]`
- Using `std` option like `c++11`
- Using precompile headers for clang

## Using precompiled headers

It can use precompiled headers for clang. *Optional*

Command for emitting precompiled header is easily access from menu.

### Emitting pch(precompiled header file),

1. Open `C`/`C++`/`Objective-C` source file on editor buffer.
2. Choose `Packages` -> `Autocomplete Clang` -> `Emit Precompiled Header`
3. Then package automatically detect emitted pch file.

![Screenshot of emit-pch](https://raw.githubusercontent.com/yasuyuky/autocomplete-clang/DocumentImage/images/autocomplete-clang-emit-pch.png)

### Notice

If you change `std` option after you emitted the pch, you should emit pch again.


## Settings

![Screenshot of configuration](https://raw.githubusercontent.com/yasuyuky/autocomplete-clang/DocumentImage/images/autocomplete-clang-settings.png)

## Keymaps

### Default keymaps

`ctrl+alt+/`: toggle

Also you can customize keymaps by editing ~/.atom/keymap.cson
(choose Open Your Keymap in Atom menu):

```cson
'.workspace':
  'ctrl-alt-/': 'autocomplete-clang:toggle'
  'cmd-ctrl-alt-e': 'autocomplete-clang:emit-pch'
```

See Customizing Atom for more details.

## License

MIT (See License file)

## Misc

- Motivation of the original author is `C++`,
  So that tests for `C`/`Objective-C` may be not enough.

- Any casual feedbacks to [@yasuyuky](https://twitter.com/yasuyuky) are welcome.
