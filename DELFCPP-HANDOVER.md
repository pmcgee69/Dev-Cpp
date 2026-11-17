# DelfCpp: handover

**DelfCpp** is the user's project to take Dev-C++ (their fork, `pmcgee69/Dev-Cpp`) to Win64 and
then, one unit at a time, into **Delf**, the user's stricter Delphi (delfc translates `.delf` to
`.pas`). Written 18 Nov 2026 for a Claude Code session on another account, to carry on.

Read, in order: this file; `DELF-JOURNEY.md` (the log: principles, files, errors found and by
what, fixes, lessons, takeaways, size); `DELFCPP-TRANSCRIPT.md` (the whole discussion, the user's
words included); Delf's `docs/devcpp-delf-todo.md` (ideas to follow up).

## Where things are

| What | Where |
|---|---|
| Dev-C++ fork, branch `delf-units` | `C:\Users\User\Documents\GitHub2\Dev-Cpp` |
| Branch `dev64` (git worktree of the same repo) | `C:\Users\User\Documents\GitHub2\Dev-Cpp-dev64` |
| Delf (private repo; delfc, SPEC, docs) | `D:\Users\Perseus\Documents\Embarcadero\Studio\Projects\_CLAUDE\Delf` |
| delfc | `Delf\poc`, run as `python -m delfc file.delf -U <unit dirs> --ns <scopes> --check` |
| DelfPascal (public Delf site/spec) | GitHub `DelfPascal`; spec v0.1 published |
| Tools for this project | `Dev-Cpp\delfcpp-tools\` (below) |
| Delphi | Delphi 13 (Studio 37.0), `C:\Program Files (x86)\Embarcadero\Studio\37.0\bin` |
| Test copies of Dev-C++ | beside `C:\Dev-Cpp\devcpp.exe` as `devcpp64-test.exe` (own .ini) |

## Branches and state (all local; nothing of DelfCpp is pushed)

| Branch | Head | What |
|---|---|---|
| `master` | = upstream | |
| `hidpi-toolbar-icons` | `d3914d1` (**pushed**) | HiDPI toolbar, labels, zoom, positions kept |
| `dev64` | `7c9a568` | Win64 port (`dcef9cf`), then plain-Delphi fixes inspired by the Delf units |
| `delf-units` | latest | Units in Delf, built through delfc, plus the log and this handover |

Units in Delf: **IntList** (`2797fce`), **EditorList** (`b3437a0`), **Instances** (`dee5f73` pass 1,
`76f8a86` fixes). Plain fixes on `dev64`: `ca0effe`, `6ea85d8`, `1197288`, `7c9a568`; on both:
`Utils.SetPath`. 20 errors logged (Claude 17, dcc64 2, test 1, Delf's rules 0).

**Next:** the fourth unit, proposed `VCL\ClassBrowsing\CppTokenizer` (the class browser; uses
IntList's neighbours). Then onward through the class browser (`CppPreprocessor`: its `#if`
operands are read with 32-bit `StrToIntDef`; `CppParser`).

## The principles (the user's; see the journey for their words)

1. **One unit at a time, stacked**: each rewritten, checked and in use before the next.
2. **Two passes per unit**: pass 1 = rename to `.delf` + `{ delf: migrate }` + the fewest changes
   that build and behave the same (the "door": delfc's output should equal the original);
   bugs found are fixed as their own commit, the same text on `delf-units` and `dev64`. Pass 2,
   later: idiomatic Delf. "We can always adjust as we go."
3. **Own branches**: this can't go upstream.
4. **Log the whole journey** in `DELF-JOURNEY.md`: each file, each error and **what found it**
   (Claude reading / a Delf rule / dcc64 / a test), fixes, lessons, takeaways, size.
5. **`dev64` in parallel**: plain-Delphi versions of the fixes, where they come up.
6. Ideas to follow up go to Delf's `docs/devcpp-delf-todo.md`, **not** `BIG_TODO.md`; events go
   to the journey's Log.
7. **Working style** (the user, 18 Nov): keep going, but stop briefly between units for input;
   they work alongside. Don't run long chains without a glance.

## The per-unit recipe

1. `git mv X.pas X.delf`; add `{ delf: migrate }` on its own line in the opening comments.
2. Transpile (step below); compare delfc's `.pas` with the original: should be identical but the
   marker. Commit "X in Delf, pass 1".
3. Read the whole unit for bugs; check who calls what (`grep`), live vs dormant. Fix in the
   `.delf` and in `dev64`'s `.pas` with one script (keeps bytes, latin-1, and line endings).
4. Test: a differential test where the unit is a library (`delfcpp-tools\IntListDiff.dpr`: old
   renamed `XOld`, seeded random ops, compare everything); the app's own `Tests.pas` via the
   temporary hook (`runtests_patch.py`, **never commit it**); or drive the app (`copydata.ps1`,
   `clickwin.ps1`, `cropwin.ps1`, `classtree.ps1`).
5. Build Win32 and Win64 on both branches; run.
6. Update `DELF-JOURNEY.md` (rows in files/errors/fixes, lessons, takeaways, size via
   `size.py <repo> delf-units`, a Log entry) and `devcpp-delf-todo.md` (commit + push Delf).
7. Grep the codebase for the class of each bug found (Instances' `SizeOf`-as-character-count
   found `Utils.SetPath`).

## Building

- `delfcpp-tools\build_devcpp_map.bat` (Win32) and `build_repo64.bat` (Win64) build the main
  checkout; `build_dev64.bat` builds `dev64` for both. Outputs land beside the scripts (git-ignored).
- `devcpp.dproj`'s pre-build event runs `Source\DelfUnits.cmd`: with env `DELF_POC` set to
  `Delf\poc` it transpiles every `.delf`; without it the committed `.pas` files are built.
- **Needed once on a machine**: all embedded VCL styles in `37.0\Styles` (GetIt installs
  `MaterialPattensBlue.vsf` misspelled: copy to `MaterialPatternsBlue.vsf`);
  `VCL\vcl-styles-utils\Common\AwesomeFont.RES` made with brcc32 (git-ignored).
- delfc from a PowerShell call works; from bash, `cmd //c DelfUnits.cmd` fails to find it.

## Traps, learned the hard way

- **delfc writes CRLF and refuses to overwrite a `.pas` whose bytes changed since it wrote it.**
  Never normalise generated `.pas` line endings; commit them as written.
- **The user's checkout has many CRLF-only modified files.** Commit only real edits; when a file's
  endings flipped, stage the LF version (`git hash-object -w` + `git update-index --cacheinfo`).
  Commit with explicit paths (`git commit -- path`), not `-a`, in the main checkout.
  `Source\Actions.pas` and others there are untracked and not ours: leave them.
- **Scoped enums**: a `.delf` unit's enums come out scoped and break plain callers. Pass 1:
  `{ delf: scopedenums off }` (SPEC §3.2). Or constant aliases (EditorList, `const lstLeft =
  TLayoutShowType.lstLeft;`), tested and in use.
- **delfc drops comments inside `match` arms** (todo §5).
- `Tests.TestEditorList` is stale (focus asserts); `TestAll` skips it.
- latin-1 files (`devCFG.pas` and others): edit with Python, bytes in and out, not the Edit tool.
- The IntList `int64 = integer` alias is gone on both branches; old notes may mention it.

## Rules from the user (memory)

- **No heredocs** in shell commands, ever: write a file, then `git commit -F file`.
- **Dev-C++ fork commits**: `Co-Authored-By` line, **no** Claude session links. Delf repo commits:
  `Co-Authored-By` + `Claude-Session` lines, then `git pull --rebase --autostash` and push (every
  Delf change is committed and pushed; parallel sessions commit there).
- **Ask before pushing** the fork (or any public repo), pull first; show any PR/issue text first.
- Don't publish unreported bugs in others' code to DelfPascal. Keep the user's email private.
- The user's pronouns aren't stated: they/them.
