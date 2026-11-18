# Dev-C++'s class browser in WebAssembly

The class browser's chain, **preprocessor → tokenizer → parser** (`CppPreprocessor`, `CppTokenizer`,
`CppParser`, with `IntList`, `StatementList`, `cbutils`, `CharUtils`), compiled to WebAssembly by
Free Pascal's `wasm32-wasip1` target and run in Node. Its output on upstream's parser corpus
(`Source\Tests\Parser`, 18 files with the STL headers) is compared with `delfcpp-tests\golden`,
recorded from upstream `master` built by dcc32 for Windows.

**Result, 18 Nov 2026:**

| Version | WebAssembly | Corpus vs the Windows golden files |
|---|---|---|
| original (upstream `master`) | **doesn't compile**: `IntList.Error`'s x86 assembler (`MOV EAX,[EBP+4]`) | — |
| `dev64` (plain Delphi, DelfCpp's fixes) | 3.35 MB | **18 of 18 identical** |
| Delf (`delfcpp-units`, delfc's output) | 3.35 MB | **18 of 18 identical** |

The code is 2004-era Delphi: no inline variables, no anonymous methods, which is the dialect
Free Pascal's Delphi mode handles. What it took, all in the build's copy of the source
(`build-wasm.ps1`; the repository's units are unchanged):

| | What | Why |
|---|---|---|
| 1 | `{$MODE DELPHIUNICODE}` | Dev-C++ assumes `Char` is 2 bytes; FPC's plain Delphi mode makes it 1 |
| 2 | `{$IFDEF MSWINDOWS}` (upstream `WIN32`) around uses clauses made unconditional | WASI isn't Windows; nothing else is guarded |
| 3 | `Windows` (empty), `System.AnsiStrings` (`StrComp`, `StrIComp`) stand-ins in `shim\`; `Dialogs`, `ComCtrls`, `Forms` dropped | named in uses clauses, unused (`Windows`), or two calls |
| 4 | `System.SysUtils`, `System.Character` → FPC's plain names | FPC's units aren't scoped here |
| 5 | `at ReturnAddress` → `at get_caller_addr(get_frame)` | Delphi's intrinsic, FPC's spelling |
| 6 | `DefOperatorChars` lists `'!'` twice | dcc accepts it; FPC calls it an error. A real slip upstream, found by a second compiler |
| 7 | `CharUtils`' two inline loop variables hoisted | FPC has no inline variables (Embarcadero-era code in `CharUtils`) |
| 8 | `ExtractStrings(…, PChar(…))` given `PAnsiChar(AnsiString(…))` | FPC's RTL is AnsiString-based; macro arguments are ASCII, so lossy only past it |
| 9 | Delf version only: `noreturn` dropped; `IntList.ExchangeItems`' inline `var Temp` hoisted | delfc's output: FPC forbids `raise` in a `noreturn` routine, and has no inline variables |

Items 7 and 9 are the gap Delf's own FPC experiment met (Delf `docs/current-thoughts.md` §5.1):
inline variables. A delfc output mode for FPC would write them hoisted (delfc knows their types)
and leave out `noreturn`.

## Running it

1. The compiler, once: Delf's `experiments\wasm\fpc-331-18863\setup.ps1 -Work $env:LOCALAPPDATA\delf-wasm`
   (builds FPC's wasm32 cross compiler and RTL from the local FPC source; RAD Studio's `ld.lld`
   is the linker). Under Windows PowerShell 5.1 its `make crossall` "fails" at the end by design
   (`utils\fpcm` isn't copied); run the RTL step after it by hand if the script stops there.
2. `.\build-wasm.ps1 -Version dev64` (or `delf`, `original`): builds `out\<version>\ParseCorpus.wasm`
   and runs the corpus through it (`run-corpus.mjs`, Node's WASI).

`ParseCorpus.dpr` builds with dcc32 too, and natively gives the same golden output.
