# CppTokenizer in Rust

Dev-C++'s class browser tokenizer, ported by hand from `Source\VCL\ClassBrowsing\CppTokenizer.delf`
to Rust (`src\lib.rs`), to see how far Delf sits from Rust. It keeps every behaviour of the
original, DelfCpp's fixes included, and is checked against the Delphi token for token.

**Result, 18 Nov 2026:**

| Corpus | Files | Tokens | Delphi, dev64 | Delphi, Delf | Rust, native | Rust, WebAssembly (Node) |
|---|---|---|---|---|---|---|
| upstream's parser corpus (`Source\Tests\Parser`) | 21 | 11,364 | reference | identical | identical | identical |
| every header in TDM-GCC-64 | 3,137 | 4,005,838 | reference | identical | identical | identical |

The WebAssembly build is 121 KB. Run times for the GCC headers were 60 to 95 s for the Delphi
dumps and 5 to 7 s for Rust. That gap isn't explained yet, and it includes each program's own
output code.

`.\compare.ps1 [-Corpus parser|gcc|all] [-Wasm]` builds `TokDump.dpr` with dcc32 against both
Delphi versions, plus the Rust `tokdump`, runs them all over the same files, and compares the
dumps. Files are read as Latin-1 (one byte, one character) on both sides, so the text is the
same. `cargo test` runs the port's own tests.

## What the port found

Marked `DELPHI:` in the source. The numbers are DELF-JOURNEY's.

- **25.** `GetForInit` is a `String` function that never assigns `Result`. Delphi compiles it, and
  the caller happens to get `''`. rustc refuses the equivalent.
- **26.** `SimplifyArgs` reads `Output[Length + 1]`, one past the end. Delphi reads the string's
  `#0`. Rust's indexing panics, so the port reads it as 0 on purpose.
- **27.** `SimplifyArgs`' "remove all before" never removes anything, because it starts at the
  comma, not before it. So `(int a , int b )` keeps its spaces. The corpus shows this in GCC's
  headers.
- **Observed:** a `:` in a comment after `#include` (`// … std::allocator.`) makes `StrToInt`
  raise, and the file's remaining tokens are lost. This happens in 21 GCC headers, read raw.
  The port returns `Err` at the same point.

## Delf to Rust, construct by construct

CppTokenizer is pass 1, so this is really old Delphi to Rust. Delf's own changes so far
(`match`, scoped enums, `noreturn`) don't occur in this unit.

| Delf / Delphi | Rust | Notes |
|---|---|---|
| `PChar` walking a text that ends in `#0` | an index into `Vec<u16>` that ends in `0` | Each `(pCurrent + 1)^` is `self.t[self.cur + 1]`. A read past the end panics, so errors 21 to 23 would have shown at once instead of reading on. |
| `string` (UTF-16, 1-based) | `Vec<u16>` | Rust's `String` is UTF-8 and byte-indexed, so it's the wrong model for code doing index arithmetic. `SimplifyArgs` keeps 1-based helpers (`o1`, `delete`) so it reads line for line against the original. |
| `Delete`, `Insert`, `Pos`, `PosEx`, `Trim`, `StrToInt` | small functions with the same edge cases (clamping, `Val`'s formats) | That's where faithfulness costs the most. |
| `TSetOfChar` / `TSysCharSet` and `in` | `fn is_space(ch) -> bool` | Plain predicates. |
| `case pCurrent^ of '"': …` | `if`/`else` chains, or `match char::from_u32(..)` | A `u16` can't be matched against `'"'` literals: friction. Delf's `match` lowers to `case`, and would lower to Rust's `match` just as directly. |
| `repeat … until C` | `loop { …; if C { break } }` | |
| `var Output: String` | `&mut Vec<u16>` | |
| nested routines (`FormatSpacesAround`, `CurrentWordEquals`) | nested `fn`s, state passed explicitly | Rust's nested `fn`s don't see the outer locals. |
| default parameters | explicit arguments | |
| an exception (`EConvertError` from `StrToInt`) | `Result<_, TokError>` and `?` | The signatures now show which routines can fail: `get_next_token` and `get_for_init`, through recursion. |
| a function result never assigned | a compile error | Error 25. |
| `TList` of `PToken`, `New`/`Dispose` | `Vec<Token>` | The freeing loops in `Reset` and `Destroy` go away. |
| `TComponent`, `Register` (the designer) | dropped | A tokenizer needs no owner. |

**So:** the bugs DelfCpp found and fixed by reading (21 to 23) are ones Rust would have turned
into panics, and Delf's rules don't reach them yet. That's the case for a bounds-checked text
cursor in Delf (`docs/devcpp-delf-todo.md`). A delfc back end that writes Rust looks feasible
for code shaped like this: pointer walking becomes indexes, sets become predicates, exceptions
become `Result`. The hard parts are the RTL string routines' edge cases and class hierarchies,
which this unit doesn't have.
