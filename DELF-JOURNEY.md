# DelfCpp: the journey (Dev-C++ into Delf)

A log of moving Dev-C++ to 64-bit and then, unit by unit, into **Delf** (Delphi with a stricter
type system; delfc translates `.delf` to `.pas`). Kept as it happens: what was changed, what
was found, what it cost, and **what found each bug** (Claude reading the code, a Delf rule,
the Delphi compiler, or a test), so the log can say honestly what Delf itself contributed.

## Principles (the user, 18 Nov 2026)

- **One unit at a time, stacked.** Each unit is rewritten, checked and in use before the next.
- **Its own branches.** This work changes the code's language, so it can't go back upstream.
- **Log the whole journey**: the bugs found, and by what; the project's size as it goes.
- **A parallel plain-Delphi branch, `dev64`**, takes the Delphi changes that the Delf
  rewrites inspire, where they come up: the same bug fixed without Delf.
- **Two passes per unit** (the user, 18 Nov: *"just get it working for delf migrate ... then make
  it idiomatic after"*). Pass 1: rename to `.delf` with `{ delf: migrate }`, the fewest changes
  that build and behave the same, bugs found logged (and fixed on `dev64`). Pass 2, later:
  idiomatic Delf (`match`, no `with`, typed sentinels, the migrate marker removed). From
  Instances on; IntList and EditorList had both passes at once. "We can always adjust as we go."
- **Tests first, one test for both versions** (the user, 18 Nov: *"Creating and applying tests ..
  v important"*; *"a single test for both the Delf code and the Delphi version. This is a great
  argument for functions that don't mess with state too much."*). `delfcpp-tests\` (DUnitX), the
  same source on both branches, is built against the original units, `dev64` and `delfcpp-units`,
  Win32 and Win64 (`run-tests.cmd`). The original fails the Regression tests: the bugs pinned.
- *"The door holds for the file" was wishful thinking.* A `.delf` unit's enumerations are
  scoped in its output, which reaches into the plain units that use it. Maybe Delf's
  `{ delf: migrate }` can play a role there (Delf's BIG_TODO item 14).

## The branches

| Branch | From | What |
|---|---|---|
| `hidpi-toolbar-icons` | `master` | HiDPI toolbar, labels, zoom (pushed) |
| `dev64` | `hidpi-toolbar-icons` | Win64 build (`dcef9cf`), then plain-Delphi fixes inspired by the Delf units |
| `delfcpp-units` | `dev64` at `dcef9cf` | Units rewritten in Delf, built through delfc (this log) |

## Size

Lines and files in the committed tree (`.pas`, `.delf`, `.dfm`, `.dpr`, `.inc`; lines are
newlines). "Own" is Dev-C++'s code; bundled libraries (SynEdit, SVGIconImageList,
vcl-styles-utils, DDetours, Abbrevia) and the separate tools (Packman, PackMaker) are counted apart.

| When | Own `.pas` | Own `.delf` | Own `.dfm` | Own `.dpr`+`.inc` | Tools (all kinds) | Bundled (all kinds) |
|---|---|---|---|---|---|---|
| `master` (start) | 106 files, 56,752 lines | 0 | 68 files, 45,689 lines | 23 files, 1,530 lines | 43 files, 36,839 lines | 392 files, 258,655 lines |
| `delfcpp-units` after IntList | 106 files, 57,189 lines¹ | 1 file, 418 lines | 68 files, 45,690 lines | 23 files, 1,530 lines | unchanged | unchanged |
| `delfcpp-units` after EditorList | 106 files, 57,201 lines¹ | 2 files, 1,068 lines | 68 files, 45,690 lines | 23 files, 1,530 lines | unchanged | unchanged |
| `delfcpp-units` after Instances | 106 files, 57,210 lines¹ | 3 files, 1,235 lines | 68 files, 45,690 lines | 23 files, 1,530 lines | unchanged | unchanged |

¹ Includes the generated `.pas` of each Delf unit. Units in Delf so far: **3 of 106** (1,264
of ~56,750 original lines, 2.2%).

## Files attacked

| # | Unit | Lines (before → `.delf`) | `delfcpp-units` | `dev64` | Checked by |
|---|---|---|---|---|---|
| 1 | `VCL\ClassBrowsing\IntList` | 445 → 418 | `2797fce` | `ca0effe` | Differential test, 1.2M operations, Win32 + Win64; class browser in the 64-bit build |
| 2 | `EditorList` | 661 → 650 | `b3437a0` | `6ea85d8` | Dev-C++'s own `TestEditorList` (switched off upstream), run in both 64-bit builds: same result in each (see below) |
| 3 | `Instances` | 158 → 167 | `dee5f73` (pass 1), `76f8a86` (fixes) | `1197288` | Pass 1 the door: delfc's output = the original byte for byte, but the marker comment. Then builds, both branches and platforms; `WM_COPYDATA` sent to the 64-bit build, with and without a terminator |
| 4 | `VCL\ClassBrowsing\CppTokenizer` | 804 → 815 | `d79bf6b` (pass 1), `289ae81` (fixes, tests) | `16f2ad6` | **The first unit with committed tests**: `delfcpp-tests`, 19 DUnitX tests, the same source run against the original, `dev64` and Delf, Win32 + Win64 |

## Errors found

**All of these are upstream code** (checked 18 Nov: the Win64 port, `dcef9cf`, touches none of
the faulty lines). Those whose Effect starts "Win64:" (1-8) are correct on Win32 and break only
in a Win64 build: IntList's `[EBP+4]` is the right way to find a caller on x86. The rest bite
upstream's own Win32 builds too; for CppTokenizer the tests show it, run against `master`
itself (Win32: 5 regression tests fail).

**Found by**: *Claude* (reading the code, while porting or rewriting), *Delf* (a Delf rule or
delfc), *dcc64* (the Delphi compiler refusing it for Win64), *test* (a test showed it), *Rust*
(rustc refusing the code as written, in the hand port, `delfcpp-rust`).

| # | Where | The bug | Effect | Found by | Fixed in |
|---|---|---|---|---|---|
| 1 | 14 units | `{$IFDEF WIN32}` around uses clauses (Kylix era) | Win64: those units have no uses at all | dcc64 | `dcef9cf` |
| 2 | `ExceptionFrm` | Inline asm to read the stack pointer | Win64: no inline asm in a Pascal routine | dcc64 | `dcef9cf` |
| 3 | `Editor`, `EditorList`, `main` | An editor kept in `Tag` through `integer(Self)` | Win64: the pointer cut to 32 bits, turned back into a `TEditor` | Claude | `dcef9cf` |
| 4 | `IntList.ExchangeItems` | Objects swapped through `Integer` casts | Win64: pointers cut to 32 bits | Claude | `dcef9cf` |
| 5 | `Instances` | `EnumWindows` callback returns `Boolean`, not `BOOL`; `LParam`s as `Integer`; `GetWindowLong` for a handle | Win64: wrong sizes (unit at present unused) | Claude | `dcef9cf` |
| 6 | `main` | `LocalFree(Cardinal(...))` | Win64: a handle cut to 32 bits | Claude | `dcef9cf` |
| 7 | `ConsoleAppHostFrm` | `OpenThread`'s result held in a `DWORD` | Win64: a handle cut to 32 bits | Claude | `dcef9cf` |
| 8 | `IntList.Error` | The caller's address read with x86 assembler (`[EBP+4]`) | Win64: **every list error an access violation** (97,132 in the test) | Claude, while rewriting; the test confirmed it | `2797fce`, `ca0effe` |
| 9 | `IntList.Find` | `L := L + 1` for `L := I + 1` | A binary search in linear time; answers right | Claude, while rewriting | `2797fce`, `ca0effe` |
| 10 | `IntList` | Exports `int64 = integer` | Every user's `Int64` silently 32-bit (`CppPreprocessor`'s `#if` arithmetic) | Claude, while rewriting; the test program's own counter wrapped | `2797fce`, `ca0effe` |
| 11 | `IntList.LoadFromStream` | `Read`, not `ReadBuffer` | A short file loads garbage, silently | Claude, while rewriting | `2797fce` |
| 12 | `EditorList.GetVisibleEditors` | Split view: the left editor returned as the right one too | After editor options change, the right pane isn't repainted | Claude, while rewriting | `b3437a0`, `6ea85d8` |
| 13 | `EditorList.CloseEditor` | *Suspected:* returns True for an `InProject` editor the project doesn't hold, without closing it | `CloseAll` would loop forever | Claude, while rewriting | flagged only |
| 14 | `Tests.TestEditorList` | Stale: expects the right pane focused after opening editors there; switched off in `TestAll` | The test fails at its step "Open explicitly in the right page control", original and Delf alike (through the test switch too) | test (run for this project) | not changed |
| 15 | `Instances.GetSentStructData` | Reads another process's `WM_COPYDATA` text up to a terminator, ignoring `cbData` | Live: any process can make Dev-C++ read past the data | Claude, while rewriting | `76f8a86`, `1197288` |
| 16 | `Instances` (3 calls) | `SizeOf(Buffer)` (bytes) as a count of characters to `GetClassName`, `GetModuleFileName(Ex)` | Windows may write 1,024 characters into 512 (dormant: single-instance code is off) | Claude, while rewriting | `76f8a86`, `1197288` |
| 17 | `Instances` callback | Process handle not closed when `GetModuleFileNameEx` fails | A handle leak (dormant) | Claude, while rewriting | `76f8a86`, `1197288` |
| 18 | `Instances.GetPreviousInstance` | `while True` waits for a window that may never match | Hangs at startup if the mutex is another Dev-C++ exe's (dormant) | Claude, while rewriting | `76f8a86`, `1197288` |
| 19 | `Utils.SetPath` | `GetEnvironmentVariable` given `SizeOf` (4,098) for a 2,049-character array | A PATH of 2,049..4,097 characters overruns the stack; longer appends junk (dormant: callers skip that branch; this machine's PATH is 2,529) | Claude, grepping for the class #16 belongs to | `9c8ce9e`, `7c9a568` |
| 20 | `Tools\Packman\InstallFiles` | Same class: `GetWindowsDirectory`/`GetSystemDirectory` given `SizeOf` (2,050) for 1,025 characters; and `SysDir` given `WinDir`'s size | Overrun only with a Windows directory past 1,025 characters | Claude, same search | not changed (separate tool) |
| 21 | `CppTokenizer.SkipDoubleQuotes`, `SkipSingleQuote` | An unterminated literal at the end, or a `\` before the `#0`, steps over the terminator | Live: the class browser reads on through memory past the text (unterminated strings are common while typing) | Claude, while rewriting; the tests show it | `289ae81`, `16f2ad6` |
| 22 | the same routines | After an escape the loop skips a character | Live, **in well-formed code**: `"\\\\"` and `"\n\\"` lose their closing quote and swallow the code after | Claude, tracing #21 | `289ae81`, `16f2ad6` |
| 23 | `CppTokenizer.GetWord` | `a[` at the end steps past the `#0` | Live: reads past the text; on Win64 a token picked up another string from the heap | Claude, while rewriting; the tests show it | `289ae81`, `16f2ad6` |
| 24 | `CppTokenizer.OpenFile`, `OpenStream` | Bytes allocated, terminator written at a character offset; ANSI bytes read as UTF-16; buffer never freed | Heap overrun and leak (dormant: unused) | Claude, while rewriting | logged only |
| 25 | `CppTokenizer.GetForInit` | A `String` function that never assigns `Result` | Dormant: the caller happens to get `''`, which is what it needs | **Rust**: the port can't compile it as written | logged; kept in the port as `Ok(Vec::new())` |
| 26 | `CppTokenizer.SimplifyArgs` | Reads `Output[Length + 1]`, one past the end (the "remove before" test when `Head = Index = Length`) | Harmless: Delphi reads the string's `#0`, which counts as blank. Range checks on would raise | Claude, porting to Rust (Rust's indexing panics there) | logged; the port reads it as 0 explicitly |
| 27 | `CppTokenizer.SimplifyArgs` | "Remove all before" starts at the comma itself, which isn't blank, so it never removes anything | Live, cosmetic: argument lists keep a space before `,` and `)` (`(int a , int b )`; the comment's aim is `(int a, int b)`); seen in GCC's headers | Claude, porting to Rust; the corpus shows it | logged |
| 28 | `VCL\SVGIconImageList\Source\SVGIconImageList.inc` (the bundled library) | Its compiler-version table stops at Delphi 11, so Delphi 12 and 13 get none of its feature defines and no published `Scaled` | Built with Delphi 12 or later, every form load stops on "Property Scaled does not exist" (`DataFrm`'s five `TSVGIconImageList`s) | running it: the error dialog (seen again by the user, 18 Nov, in a fresh build of `master`) | `dcef9cf` |
| 29 | `SynEdit`, `ecLineBreak` with auto-indent | Enter at the end of an indented line moves the caret, then types the indent through the selection, which is still at the old caret. So the indent's undo record also spans the line break, and undo removes that line twice | Live: undo after two braced lines raises `ESynEditStringList: Invalid stringlist index` (upstream `master`, every build). This is the one test upstream's own menu ran, `TestEditor`; the folds had nothing to do with it | test: the test switch; narrowed by cut-down runs and the undo list's records. **Reported upstream at least 10 times, 2021 to 2025**, all but one open: Embarcadero/Dev-Cpp #129, #146 (an exact repro: brackets, a new line, Ctrl+Z deletes the line below), #183 and #223 (users found that turning off Auto Indent avoids it), #192, #234, #238, #252, #273, #338 | `f75118a`, `36475ff` |
| 30 | `SynHighlighterCpp.InitIdent` | The keyword table was regenerated (91 keywords, hash mod 331) but `FuncAsm` still sits on the old table's slots 70, 191 and 189, now empty, and the function table kept the old size (343), so it reads past `KeyIndices` | Live: an identifier hashing there (`df`, `mo`, `eeee`: 165 of the 18,278 of one to three letters) calls `FuncAsm(-1)` and reads `KeyWords[-1]`. That's garbage on Win32 and **an access violation on Win64 while typing**. `asm` itself (slot 250) never got `FuncAsm` | test: the test switch, once #29 was fixed; the stack from its exact Win64 unwind. Not reported upstream: their releases are 32-bit, where it reads garbage quietly. It began with the fix for #47 ("Some C++ keywords not highlighted", 2020: the maintainer re-patched the keywords after upgrading SynEdit, `cb4a4a5`, 29 Oct 2020) | `f4eb82f`, `588493d` |
| 31 | `Editor.TSynEditEx.CommandProcessor` | Dev-C++'s extra indent after `{` or `:` on Enter, and the indent it removes when `}` is typed, are written straight into `Lines`, with no undo record | Live: undo and redo put indentation in the wrong places | test: `TestUndo`, the redo cycles of #252 (the undo and redo records written out) | `209e997`, `1ff9c40` |
| 32 | `SynEdit.RedoItem` | Redo replays a line break through `CommandProcessor(ecLineBreak)`, so auto-indent and the editor's additions run again, and the redo records after it restore that indent too | Live: every redo-all leaves stray tabs (the reports' "redo strays even further", #192, #252, #273) | test: `TestUndo` | `d7d0bf4`, `f3caeef` |

**Not bugs, but made explicit by a Delf rule:** `IntList.Add`'s `case` on `TDuplicates` had no
`dupAccept` arm (the fall-through was right). Delf's `match` must cover every value, so the
arm is now written (*Delf*; `dev64` states it too).

**Observed, not counted:** in a raw header, an `#include` line with a `:` in a trailing comment
(`// … std::allocator.`) makes `StrToInt` raise, and the file's remaining tokens are lost (21 of
GCC's 3,137 files). The class browser tokenizes the preprocessor's output, not raw headers, so
whether it bites there is unchecked.

**Tally so far:** Claude 23 (one suspected), dcc64 2, test 5, running it 1, Rust 1, Delf 0 (rules made correct code explicit). Delf's
part has been the occasion: rewriting a unit means reading all of it.

## Tests (delfcpp-tests)

One DUnitX source, the same on both branches, built against three versions of the units by
unit path alone: the original (upstream master on Win32; master plus only the Win64 port on
Win64), dev64 and Delf, each on Win32 and Win64 (run-tests.cmd). 62 tests on 18 Nov: dev64
and Delf pass all; the original fails 11 on Win32 and 13 on Win64, and is crashed by the
CrashesOriginal tests. Upstream's own parser corpus (Source/Tests/Parser) is among them.

**Upstream's in-app tests, through the test switch** (`0119e98`, `cad9b3d`):
`devcpp.exe -c <config> -runtests <results> [-tests editor,editorlist,actions,compileroptions]`
runs `Tests.pas` once the window is up, writes PASS or FAIL per test (the exception, the step)
and closes with exit code 0 or 1. `delfcpp-tests\run-app-tests.ps1` runs any number of builds,
each as a copy beside the installed Dev-C++ with a copy of an existing config. The default is
`editor,editorlist`: `actions` opens every dialog, and `compileroptions` deletes and saves the
compiler sets. 18 Nov: upstream `master` (Win32, plus error 28's build fix only), `dev64` Win32
and Win64, and Delf Win64 all give the same result. `TestEditor` fails (error 29) and
`TestEditorList` fails (error 14). After errors 29 and 30 were fixed, `TestEditor` **passes** on
`dev64` (Win32, Win64) and Delf (Win64); `TestEditorList` still fails at its stale check.
A failure gives its code address and stack (exact on Win64), and `delfcpp-tools\mapaddr.ps1`
names them from the build's `.map` (`build_dev64.bat` now writes one, with line numbers).

| Error | Pinned by (Regression tests; the original fails them) |
|---|---|
| 1, 2 | The Win64 build itself: master doesn't compile for Win64 |
| 8 | IntList: BadIndexRaisesListError, DuplicateErrorRaises (Win64 only: access violations) |
| 9 | IntList: FindIsABinarySearch (1,000 misses in a million items: 550-800 ms before) |
| 10 | IntList: Int64IsStill64Bits (SizeOf(Int64) was 4 in a unit using IntList) |
| 11 | IntList: ShortStreamRaises (it also caught dev64 missing this fix) |
| 12 | EditorList: SplitViewVisibleEditors |
| 15 | Instances: ReadsOnlyCbData (the original returned memory past the message as a file name) |
| 19 | Utils: SetPathLongPath, CrashesOriginal (the original dies: access violation or stack overflow) |
| 21-23 | CppTokenizer: DoesNotReadPastTheEnd, seven cases |
| 29, 30 | The test switch: `TestEditor` (the original fails it at #29; past that, Win64 builds crashed at #30) |
| not yet | 3 (editors in Tag: needs real editors; the in-app Tests.pas, which runs now but stops before it gets there), 4 (passes: the port fixed it before the tests' original), 5-7 and 16-18 (window, process and handle calls), 13 (suspected), 20 (Packman), 24 (private, unused) |

## Fixes (beyond the errors)

Changes made while a unit was rewritten that fix no bug but remove a hazard or a smell.

- **IntList**: a dynamic array, not `ReallocMem` behind a pointer to an array of `MaxInt div 32`
  items (no pointer arithmetic, no casts; frees itself); no `with`; `FUpdateCount`, never set,
  removed; `Error` marked `noreturn`; `Add`'s duplicate rule a `match` over every value.
- **EditorList**: four `case`s on the layout became `match`es (two had `else` arms no value could
  reach); `with` gone from `GetPreviousEditor` (flattened to early exits); `GetEditorFromTag`
  stops at its first match; `UpdateLayout`'s last `else if`, always true, a plain `else`.
- **Instances**: none yet. Pass 1 only (the rename and `{ delf: migrate }`); its fixes are bugs (above).
- **CppTokenizer**: none beyond the bugs. Pass 1 only.

## Lessons

- **Scoped enumerations leave the unit** (IntList has none; `EditorList` will). A plain Delphi
  caller using `lstLeft` must write `TLayoutShowType.lstLeft`. The rename is not invisible to
  callers. Candidate: `{ delf: migrate }` keeps a migrated unit's enums unscoped, or warns.
- **delfc's output is CRLF**, and delfc refuses to replace a `.pas` whose bytes changed since it
  wrote it. So the generated `.pas` is committed exactly as written; nothing normalises it.
- **The build**: `Source\DelfUnits.cmd`, the `.dproj`'s pre-build event, runs delfc when
  `DELF_POC` is set; otherwise the committed `.pas` is built. Dev-C++ builds without Delf.

- **Delf already has `{ delf: scopedenums off }`** (SPEC §3.2): a file's enums stay unscoped in
  the output, so plain callers need nothing. That is the pass-1 route; the aliases (below) keep
  the type scoped and suit pass 2. Found after EditorList was done with the aliases.
- **Enum constant aliases work** (EditorList): the scoped type plus `const lstLeft =
  TLayoutShowType.lstLeft`; `Tests.pas`'s 20 unqualified uses compiled unchanged.
- **delfc drops comments inside `match` arms** (four in EditorList; one trailing comment moved
  to its own line). The `.delf` keeps them; the generated `.pas` loses them.
- **The project's own tests are worth finding and running**, even switched-off ones: a temporary
  hook ran `TestEditorList` in both builds. It needed its stale focus asserts set aside.

- **Pass 1 is cheap and exact** (Instances): rename, add `{ delf: migrate }`, and delfc's output is
  the original byte for byte. The bug fixes then go in as their own commit, the same text on
  both branches.
- **Unicode-era Win32 calls** are a class to grep for: `SizeOf` of a `Char` array given where an
  API counts characters (three in Instances).

- **One test, three versions works**: a test sees only the interface, so the same DUnitX source
  builds against the original, `dev64` and Delf by unit path alone. The original passing every
  characterization test and failing only the regression tests is the cleanest evidence yet.
- **Reads past the end vary with memory**: the original failed 5 regression tests on Win32 and
  6 on Win64; what lies past the text decides. A guard text after the `#0` makes it visible.
- **Win64 and DUnitX**: `Assert.AreEqual(6, List.Count)` doesn't compile for Win64 (`Count` isn't
  the literal's type); `AreEqual<Integer>`. **`.cmd` files**: `set` resets the error level (a
  `.bat` doesn't), and `set X=1 & ...` stores `"1 "`: take the exit code first, quote every set.

- **Upstream had tests**: Tests.pas (in-app, its action disabled, TestAll running only
  TestEditor), a test plan (Source/Tests/Document, DevTest.pdf) with a manual checklist, and a
  parser corpus (Source/Tests/Parser, 18 files with written checks). The corpus moved to DUnitX:
  the class browser's whole chain (preprocessor, tokenizer, parser) runs without a window, so
  upstream's check on Preprocessor.cpp is an assertion and every file's parsed statements are
  compared with golden files recorded from master. All three versions agree on all 18 files.
- **cbutils declares its own TFile**, hiding System.IOUtils.TFile in any unit that uses both.

## Takeaways

Updated as units land; the short version of what this project shows.

1. **So far Delf's value is the occasion, not the rules.** Rewriting a unit means reading all
   of it, and that found IntList's four bugs; no Delf rule flagged one. The rules that would
   have are listed in Delf's `docs/devcpp-delf-todo.md` §2.
2. **A differential test is what makes a rewrite safe.** Old and new side by side under random
   operations: it proved IntList unchanged, and measured the original's Win64 crash.
3. **Delf's changes reach past the file.** Scoped enums break plain callers; constant aliases
   (tested) keep the interface while the unit is migrated.
4. **Run old and new the same way and compare**, even when the test is imperfect: EditorList's
   stale test failed identically in both, then passed identically without the focus asserts.
5. **Pure code is testable code** (the user): CppTokenizer, text in and tokens out, gave the
   most bugs and the easiest tests; EditorList, all state, needed the running app. Pass 2 can
   pull pure decisions out (`LayoutFor(LeftCount, RightCount)`).
6. **Win64 is where old Delphi breaks quietly**: casts of pointers to `Integer`, x86 assembler
   that still assembles, 1-byte `Boolean` callbacks. Two of eleven errors the compiler refused;
   the rest compiled.

## Log

- **18 Nov 2026.** `win64` (the Win64 port) renamed `dev64`. IntList rewritten in Delf
  (`2797fce`), differential test identical except the original's Win64 crashes; the same
  fixes in plain Delphi on `dev64` (`ca0effe`), whose IntList now matches the Delf one exactly.
  Next: `EditorList` (the scoped enum), then `Instances`.
- **18 Nov 2026, event: enum aliases.** The scoped-enum problem met before `EditorList`: a
  `.delf` unit's enums are scoped, so plain callers writing `lstLeft` break. The user asked
  whether enums can be aliased, changing one file only. Answer, tested with dcc32: keep the type
  scoped and export a constant per value (`const lstLeft = TLayoutShowType.lstLeft;`); plain
  callers' assignments, sets, `case` labels, `in` and `for` all compile unchanged, RTTI
  names too. One type, no casts. To be written by hand in `EditorList.delf`, and proposed for
  delfc under `{ delf: migrate }`. Ideas like this one go to Delf's `docs/devcpp-delf-todo.md`.
- **18 Nov 2026.** EditorList in Delf (`b3437a0`), with the enum aliases; found the split-view
  repaint bug (fixed on `dev64`, `6ea85d8`) and a suspected endless `CloseAll`; ran Dev-C++'s
  own switched-off `TestEditorList` in both builds. Next: `Instances`.
- **18 Nov 2026.** The two-pass way adopted (the user). Instances, pass 1 (`dee5f73`, the door
  exact), then four bugs fixed on both branches (`76f8a86`, `1197288`); one live
  (`WM_COPYDATA` read past its data), three dormant in the single-instance code.
- **18 Nov 2026.** Grepped Dev-C++ for Instances' `SizeOf`-as-character-count class: two more
  (`Utils.SetPath`, fixed on both branches; Packman, logged). A bug found once is a pattern to
  search for everywhere.
- **18 Nov 2026.** CppTokenizer, pass 1 (`d79bf6b`, the door exact). Next: read it for bugs
  (804 lines; pointer-walking `PChar` code, so look for reads past the end), then fixes on both
  branches, then a differential test of the tokens it produces over real headers.
- **18 Nov 2026.** Tests made first-class (the user). CppTokenizer read: three live bugs (reads
  past the end; a misread escape in well-formed code) fixed on both branches (`289ae81`,
  `16f2ad6`), with `delfcpp-tests`: one DUnitX source, three versions, two platforms.
- **18 Nov 2026.** Upstream's tests found and brought in where they can run headless (the user:
  migrate to DUnitX where we can). delfcpp-tests: 38 tests (tokenizer 19; parser corpus 19, the
  STL headers among them). dev64 and Delf pass all; the original fails only the 6 tokenizer
  regressions. Next: tests for IntList, Instances, Utils.SetPath, EditorList (LayoutFor), and the
  in-app Tests.pas behind a test switch.
- **18 Nov 2026.** Tests for every unit so far: IntList, Instances, Utils.SetPath, EditorList,
  CppTokenizer, and the parser corpus; 62 in all. The test program links the app's units without
  starting the app, so main-bound code tests too. A shared test caught dev64 missing IntList's
  stream fix (fb29015). The original's SetPath crashes the test program outright.
- **18 Nov 2026, tangent: WebAssembly** (the user: *"It would be cool to have just wasm as our
  compile ourselves target"*). The class browser's chain compiled by Free Pascal to wasm32-wasip1
  and run in Node: dev64 and the Delf version give the Windows golden output on all 18 corpus
  files; upstream doesn't compile (IntList's x86 assembler). FPC also caught a duplicate set
  element upstream (CharUtils, "!" twice). delfcpp-wasm/ (933eac1); Delf current-thoughts §5.2.
- **18 Nov 2026.** Checkouts sorted (the user: the normal directory is the normal Win32 code):
  `GitHub2\Dev-Cpp` is upstream `master` again; this branch is a worktree, `Dev-Cpp-delf`, and
  is renamed `delfcpp-units` (was `delf-units`).
- **18 Nov 2026, tangent: Delf to Rust** (the user: *"you'd think rust might sit closer to delf ..
  but further from eg vcl"*; *"maybe this is delf -> rust .. small scope good"*). CppTokenizer
  ported to Rust by hand (`delfcpp-rust/`, 692 lines with tests), built natively and for
  wasm32-wasip1 (121 KB). Against the Delphi (dev64 and Delf, dcc32): **identical on 3,158
  files, 4,017,202 tokens** (upstream's parser corpus and every GCC header), native and in Node.
  The port found three more (25-27); rustc itself refused one. The mapping, construct by
  construct, is in `delfcpp-rust/README.md`. Next: the test switch.
- **18 Nov 2026.** The test switch: upstream's in-app `Tests.pas`, reached before only from a
  switched-off menu action, now runs unattended (`-runtests`). Its first runs hung on a save
  dialog after a failed test (fixed: the editors are discarded) and, for upstream's build, on
  error 28's dialog, which the user saw on screen. The one test upstream's menu ran,
  `TestEditor`, **fails on upstream itself**: undo after the fold steps raises (error 29).
- **18 Nov 2026.** Error 29 chased (the user's pick). Cut-down runs showed typing braces and
  undoing was enough. The undo list's records showed each auto-indented Enter recorded twice,
  and SynEdit's Enter code showed why. Fixed in two lines; `TestEditor` then ran further and
  crashed on Win64 only. The switch's stack (exact on Win64) went straight to the C++
  highlighter: a regenerated keyword table with three stale slots, so typing `df` or `mo` read
  before an array (error 30). Both fixed on both branches; `TestEditor` passes everywhere.
  Range checks (`{$R+}`) would have stopped #30 at the read on Win32 too: a test build with
  checks on is worth having.
- **18 Nov 2026.** Upstream's issues checked (the user: *"i feel like people have reported an
  issue like this"*): error 29 has been reported at least 10 times since 2021. To test the
  reports rather than assume, `TestUndo` replays them as described. Upstream fails at #146, the
  exact report. With #29 fixed, the redo reports still failed: two more bugs (31, 32), both
  fixed. `TestUndo` passes on `dev64` Win32 and Win64 and on Delf Win64.
- **18 Nov 2026, upstream.** The three undo/redo fixes (29, 31, 32) put on upstream's latest
  `master` as branch `fix-undo-autoindent` in the fork (no Win64, no project markers), tested
  there (`TestEditor` and `TestUndo` pass on Win32, with the test switch applied only for the
  run), pushed, and a PR to Embarcadero/Dev-Cpp opened in the browser for the user to submit.
  Error 30 (the highlighter) is held back for its own issue.
