# autocomplete-clang package

This package provides completions by [clang](http://clang.llvm.org/)
like [emacs auto-complete-clang.el](https://github.com/brianjcj/auto-complete-clang).

**for `C`/`C++`/`Objective-C`**

![Screenshot for how autocomplete works](https://www.dropbox.com/meta_dl/eyJzdWJfcGF0aCI6ICIiLCAidGVzdF9saW5rIjogZmFsc2UsICJzZXJ2ZXIiOiAiZGwuZHJvcGJveHVzZXJjb250ZW50LmNvbSIsICJpdGVtX2lkIjogbnVsbCwgImlzX2RpciI6IGZhbHNlLCAidGtleSI6ICJ5Njk3YWo4YnNtazQ2bjcifQ/AAIM3Oyps_9R4A_as_JNihGbdOCMCsdLNIWrSq0bzFb_hw?dl=1)

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

![Screenshot of emit-pch](https://www.dropbox.com/meta_dl/eyJzdWJfcGF0aCI6ICIiLCAidGVzdF9saW5rIjogZmFsc2UsICJzZXJ2ZXIiOiAiZGwuZHJvcGJveHVzZXJjb250ZW50LmNvbSIsICJpdGVtX2lkIjogbnVsbCwgImlzX2RpciI6IGZhbHNlLCAidGtleSI6ICI1YmRjNzM1enFkbzhmdmYifQ/AALbyL4CoIgttCvrI6H8cpUDrgKmz22hD2KZVcKu5UZoKA?dl=1)

### Notice

If you change `std` option after you emitted the pch, you should emit pch again.


## Settings

![Screenshot of configuration](https://www.dropbox.com/meta_dl/eyJzdWJfcGF0aCI6ICIiLCAidGVzdF9saW5rIjogZmFsc2UsICJzZXJ2ZXIiOiAiZGwuZHJvcGJveHVzZXJjb250ZW50LmNvbSIsICJpdGVtX2lkIjogbnVsbCwgImlzX2RpciI6IGZhbHNlLCAidGtleSI6ICJzMjVjNmlmZHA2bzg5ZzgifQ/AAKWXyBGWCqRBdeHC_VOl0bBX9PH7vlBuy_m_LIIWGFZnw?dl=1)

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
