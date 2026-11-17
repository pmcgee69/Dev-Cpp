# Dev-C++ into Delf: the journey

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
- *"The door holds for the file" was wishful thinking.* A `.delf` unit's enumerations are
  scoped in its output, which reaches into the plain units that use it. Maybe Delf's
  `{ delf: migrate }` can play a role there (Delf's BIG_TODO item 14).

## The branches

| Branch | From | What |
|---|---|---|
| `hidpi-toolbar-icons` | `master` | HiDPI toolbar, labels, zoom (pushed) |
| `dev64` | `hidpi-toolbar-icons` | Win64 build (`dcef9cf`), then plain-Delphi fixes inspired by the Delf units |
| `delf-units` | `dev64` at `dcef9cf` | Units rewritten in Delf, built through delfc (this log) |

## Size

Lines and files in the committed tree (`.pas`, `.delf`, `.dfm`, `.dpr`, `.inc`; lines are
newlines). "Own" is Dev-C++'s code; bundled libraries (SynEdit, SVGIconImageList,
vcl-styles-utils, DDetours, Abbrevia) and the separate tools (Packman, PackMaker) are counted apart.

| When | Own `.pas` | Own `.delf` | Own `.dfm` | Own `.dpr`+`.inc` | Tools (all kinds) | Bundled (all kinds) |
|---|---|---|---|---|---|---|
| `master` (start) | 106 files, 56,752 lines | 0 | 68 files, 45,689 lines | 23 files, 1,530 lines | 43 files, 36,839 lines | 392 files, 258,655 lines |
| `delf-units` after IntList | 106 files, 57,189 lines¹ | 1 file, 418 lines | 68 files, 45,690 lines | 23 files, 1,530 lines | unchanged | unchanged |
| `delf-units` after EditorList | 106 files, 57,201 lines¹ | 2 files, 1,068 lines | 68 files, 45,690 lines | 23 files, 1,530 lines | unchanged | unchanged |

¹ Includes the generated `.pas` of each Delf unit. Units in Delf so far: **2 of 106** (1,106
of ~56,750 original lines, 1.9%).

## Files attacked

| # | Unit | Lines (before → `.delf`) | `delf-units` | `dev64` | Checked by |
|---|---|---|---|---|---|
| 1 | `VCL\ClassBrowsing\IntList` | 445 → 418 | `2797fce` | `ca0effe` | Differential test, 1.2M operations, Win32 + Win64; class browser in the 64-bit build |
| 2 | `EditorList` | 661 → 650 | `b3437a0` | `6ea85d8` | Dev-C++'s own `TestEditorList` (switched off upstream), run in both 64-bit builds: same result in each (see below) |

## Errors found

**Found by**: *Claude* (reading the code, while porting or rewriting), *Delf* (a Delf rule or
delfc), *dcc64* (the Delphi compiler refusing it for Win64), *test* (a test showed it).

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
| 14 | `Tests.TestEditorList` | Stale: expects the right pane focused after opening editors there; switched off in `TestAll` | The test fails at line 166, original and Delf alike | test (run for this project) | not changed |

**Not bugs, but made explicit by a Delf rule:** `IntList.Add`'s `case` on `TDuplicates` had no
`dupAccept` arm (the fall-through was right). Delf's `match` must cover every value, so the
arm is now written (*Delf*; `dev64` states it too).

**Tally so far:** Claude 11 (one suspected), dcc64 2, test 1, Delf 0 (rules made correct code explicit). Delf's
part has been the occasion: rewriting a unit means reading all of it.

## Fixes (beyond the errors)

Changes made while a unit was rewritten that fix no bug but remove a hazard or a smell.

- **IntList**: a dynamic array, not `ReallocMem` behind a pointer to an array of `MaxInt div 32`
  items (no pointer arithmetic, no casts; frees itself); no `with`; `FUpdateCount`, never set,
  removed; `Error` marked `noreturn`; `Add`'s duplicate rule a `match` over every value.
- **EditorList**: four `case`s on the layout became `match`es (two had `else` arms no value could
  reach); `with` gone from `GetPreviousEditor` (flattened to early exits); `GetEditorFromTag`
  stops at its first match; `UpdateLayout`'s last `else if`, always true, a plain `else`.

## Lessons

- **Scoped enumerations leave the unit** (IntList has none; `EditorList` will). A plain Delphi
  caller using `lstLeft` must write `TLayoutShowType.lstLeft`. The rename is not invisible to
  callers. Candidate: `{ delf: migrate }` keeps a migrated unit's enums unscoped, or warns.
- **delfc's output is CRLF**, and delfc refuses to replace a `.pas` whose bytes changed since it
  wrote it. So the generated `.pas` is committed exactly as written; nothing normalises it.
- **The build**: `Source\DelfUnits.cmd`, the `.dproj`'s pre-build event, runs delfc when
  `DELF_POC` is set; otherwise the committed `.pas` is built. Dev-C++ builds without Delf.

- **Enum constant aliases work** (EditorList): the scoped type plus `const lstLeft =
  TLayoutShowType.lstLeft`; `Tests.pas`'s 20 unqualified uses compiled unchanged.
- **delfc drops comments inside `match` arms** (four in EditorList; one trailing comment moved
  to its own line). The `.delf` keeps them; the generated `.pas` loses them.
- **The project's own tests are worth finding and running**, even switched-off ones: a temporary
  hook ran `TestEditorList` in both builds. It needed its stale focus asserts set aside.

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
5. **Win64 is where old Delphi breaks quietly**: casts of pointers to `Integer`, x86 assembler
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
