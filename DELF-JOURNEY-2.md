# DelfCpp: the journey, Chapter 2

Journal 2 is **Chapter 2** of DelfCpp's journal (the user, 22 Nov 2026: *"start a new journal 2"*,
then *"Journal 2 is chapter 2"*). [Chapter 1, `DELF-JOURNEY.md`](DELF-JOURNEY.md), holds the start: the principles, the branches,
units 1-4 (IntList, EditorList, Instances, CppTokenizer), errors 1-32, the tests, the fixes,
lessons, takeaways, the upstream PRs and its log to 20 Nov. Its principles still hold, and the
numbering carries on: units from 5, errors from 33, the tally from Chapter 1's.

**One of two journals** still (the user, 20 Nov): this is DelfCpp's, the Dev-C++ fork. Delf's
own process record is the Delf repo's `docs/lifetime-diagnostics-record.md`. A milestone goes in
whichever it belongs to; one that is both goes in both, each pointing at the other.

**A series** (the user, 22 Nov: *"I think this whole thing could be an ongoing series of videos.
106 units. So new chapter for the journal here."*, and *"Journal 2 is chapter 2"*). The journal
runs in chapters, each its own file: Chapter 1 the first four units and the upstream work, this
Chapter 2 from unit 5. Within a chapter, each unit has its own section in the log.

## Accidentally not breaking

The user, 22 Nov: *"I want to keep particular record of things like these that are only
accidentally not breaking problems. We'll replace them later with correct delf ideas."* Code that
works today by luck, not by design: an unwritten value that happens to be right, a read that
happens to land on something harmless, a pointer to freed memory that happens never to be read
through. Each stays here until a Delf idea makes the right version the natural one; the last
column is for that idea, **open** until then (Claude's first thoughts marked as such).

| # | Where | Why it works | What would break it | Found in | Delf idea (later) |
|---|---|---|---|---|---|
| A1 | `CppTokenizer.GetForInit` | A `String` function never assigns `Result`; Delphi hands the caller `''`, which is what it needs | A caller that passes a non-empty `Result` slot (Delphi's string results are hidden `var` parameters, so the old value can come back) | Chapter 1, error 25 (found by Rust) | Open. First thought: every path assigns `Result`, checked by delfc |
| A2 | `CppTokenizer.SimplifyArgs` | Reads `Output[Length + 1]`, one past the end; Delphi's strings end in `#0`, which counts as blank | Range checks on (raises); a `TArray<Char>` or slice instead of a string (no `#0` there) | Chapter 1, error 26 (Rust) | Open. First thought: indexing that can't step past the end, or says so in its type |
| A3 | `CppParser.InvalidateFile`, `ReProcessInheritance` | A deleted class's statement is disposed (the list owns it), but its address stays in `fInvalidatedStatements` and in other statements' `_InheritanceList`s until the reparse. Only compared, never read through | Any code that reads through one of those pointers before the reparse (a class browser hover, a debug dump), or a new statement allocated at the same address and compared as if it were the old one | Chapter 2, unit 5 | Open. A lifetime question: what may still point at a statement when its list frees it |

Related but not the same kind: Chapter 1's **dormant** errors (13, 16-20, 24) and error 33 here are
bugs that bite on rarer input or a first caller; they're in the errors tables.

## Every error along the way

The user, 22 Nov: *"We want ALL THE ERRORS recorded"*. Beside the code's bugs (the errors
table, 33 on), **everything that went wrong in doing the work**: compile failures, a tool
refusing, a script's slip, Claude's own mistakes and misreadings, each with who made it, what
caught it and what it cost. Numbered W1, W2, ... across the chapter.

**Who**: *Claude* (a slip or a wrong reading), *dcc* (the Delphi compiler), *delfc*, *tool*
(git, sed, Python, the test runner), *by design* (a refusal that was right).

| # | Unit | What went wrong | Who | Caught by | Fixed by | Cost |
|---|---|---|---|---|---|---|
| W1 | 5 | The test's header cited "error 30" for `DeleteFromTo`; Chapter 1's table already ran to 32. Corrected to 34 from a quick grep that read the wrong table (the tests table's rows), then to 33 | Claude | reading the errors table's last row | the header's number (`sed`), before the first commit | two corrections, nothing committed wrong |
| W2 | 5 | `sed -i` on the CRLF `run-tests.cmd` (to add the unit) rewrote all 208 lines' endings; the file was copied to `dev64` like that | tool (Git Bash's `sed`), Claude for using it on a CRLF file | `git diff --stat`: 208 lines changed for a one-word edit | both copies restored with `git checkout`, the edit redone on the bytes in Python | one rerun |
| W3 | 5 | **Win64 build failed**: `E2532 Couldn't infer generic type argument` at `Assert.AreEqual(Ref.Count, Got, …)`: `TList<T>.Count` is `NativeInt` on Win64, `Got` an `Integer`. **A repeat**: Chapter 1's Lessons already says *"`Assert.AreEqual(6, List.Count)` doesn't compile for Win64"* | dcc, Claude (the lesson was in the journal, not applied) | the runner: *original Win64: BUILD FAILED*, its `build.log` | `var N: Integer := Ref.Count` | one build; a lesson written down but not read |
| W4 | 5 | The first fix tried was `const N: Integer = Ref.Count` (an inline typed constant from a runtime value); replaced with `var … :=` before it was compiled, so never tested whether dcc takes it | Claude | Claude, rereading before the run | `var` | none; left unknown |
| W5 | 5 | delfc refused to write `StatementList.pas`: *exists and isn't delfc's output; not overwritten* | by design: delfc protects a `.pas` it didn't write | delfc | `--force`, right for a unit's first conversion only | one rerun; to remember for every new unit |
| W6 | 5 | `size.py` run without its arguments: `IndexError` | Claude (didn't read its usage line first) | Python | `size.py . HEAD` | one rerun |
| W7 | 5 | Python `SyntaxWarning: invalid escape sequence '\C'` in the scripts that wrote the journal (`VCL\ClassBrowsing` in a plain string). Harmless here, `\C` kept as written; it would not be for `
`, `	` | Claude | Python's warning | checked the written rows by `grep`: correct | none; raw strings next time |
| W8 | 5 | The first full run reported *"A fixed version failed or did not build"* when only the original had been run, and failed (W3) | tool (the runner's message covers any failure) | reading the per-version lines | nothing changed | none; the message misleads when one version is run |
| W9 | – | Journal 2 (and the reverted journal 1) written with CRLF over files git stores with LF: the whole file showed as changed | Claude | `git diff --stat` (867 lines) and `git diff --ignore-cr-at-eol` (the real 9) | `sed -i 's/
$//'` before committing | one check |
| W10 | – | StatementList's entries went into journal 1; the user then asked for a journal 2 (*"I forgot to say start a new journal 2"*) | not an error of the work: the instruction came after | the user | the entries moved to journal 2, journal 1 restored to 20 Nov | one restructure |
| W11 | – | *"new chapter for the journal here"* read as a chapter per unit (Chapter 5 = StatementList) | Claude (the reading was stated, but not asked) | the user: *"Journal 2 is chapter 2"* | units made sections ("Unit 5"), the journals Chapters 1 and 2; the memory note corrected | one commit, `8f1333d` |
| W12 | 5 | Not an error, recorded as one to check: the original passing the seven characterization tests could have hidden a test too weak to fail. It does fail where it should: the three regressions (*Expected [3] but got [5]*, *[0] but got [2]*) | – | – | – | – |
| W13 | – | **W7 again**, while writing W7's own row: the script holding this table raised the same `SyntaxWarning` (a `\C` in a plain string). The rows came out right | Claude | Python's warning | this row written with a raw string | none; a repeat in the same minute |

## Running tables

### Size

Continuing Chapter 1's table (`delfcpp-tools/size.py . HEAD`).

| When | Own `.pas` | Own `.delf` | Own `.dfm` | Own `.dpr`+`.inc` | Tools (all kinds) | Bundled (all kinds) |
|---|---|---|---|---|---|---|
| `delfcpp-units` after StatementList (CppTokenizer included) | 106 files, 58,112 lines¹ | 5 files, 2,290 lines | 68 files, 45,690 lines | 22 `.dpr` (204) + 1 `.inc` (1,326)² | unchanged | unchanged |

¹ Includes the generated `.pas` of each Delf unit. Units in Delf so far: **5 of 106** (2,299
of ~56,750 original lines, 4.1%).
² `size.py` counts `.dpr` and `.inc` apart.

### Files attacked

| # | Unit | Lines (before → `.delf`) | `delfcpp-units` | `dev64` | Checked by |
|---|---|---|---|---|---|
| 5 | `VCL\ClassBrowsing\StatementList` | 231 → 238 | `a7d259a` (pass 1), `3f0ea9c` (fix) | `c5ad900` | Pass 1 the door: delfc's output = the original byte for byte, but the marker. Tests first (`15f4eea`, `d661eec`): 10 DUnitX tests, among them 200,000 random operations against a `TList` with the links walked both ways; the same source on the original, `dev64` and Delf, Win32 + Win64 |

### Errors found

Same columns and "Found by" as Chapter 1.

| # | Where | The bug | Effect | Found by | Fixed in |
|---|---|---|---|---|---|
| 33 | `StatementList.DeleteFromTo` | A `break` straight after the first node's deletion, before the loop's `if Node = ToNode` test: it deletes `FromNode` alone, whatever `ToNode` is. The lines after the `break` are unreachable, and would read the freed node's `NextNode` if the `break` were taken out | Latent: nothing in Dev-C++ calls it (the parser deletes node by node). A caller would get a list with the rest of the range still in it | Claude, reading the unit; the tests confirmed it (the original deletes one node of a range of 3 or 6). delfc said nothing: Delf has no rule for statements after an unconditional `break` | `3f0ea9c`, `c5ad900` |

**Observed, not counted:** see *Accidentally not breaking* A3, above.

**Tally:** Chapter 1's (Claude 23, dcc64 2, test 5, running it 1, Rust 1, Delf 0), plus
Claude 1 here: **Claude 24**, the rest unchanged.

## Log

### Unit 5: StatementList (22 Nov 2026)

Chosen from the units with no form and few of
  Dev-C++'s own units used (the user: *"Next unit"*, then *"Go"*): the class browser's doubly
  linked list of parsed statements, hand-managed pointers. **Tests first**: `Test.StatementList`,
  10 tests, among them 200,000 random operations against a `TList` (links walked both ways every
  97 operations), on both branches (`15f4eea`, `d661eec`); 72 tests in all now. Reading it found
  **error 33**: `DeleteFromTo` deletes only its first node (a `break` before its test), latent
  since nothing calls it. The original fails the three new regressions (5 left of 6 where 3 were
  meant; 2 of 3 where none). **Pass 1** (`a7d259a`): the door exact, delfc's output the original
  but the marker; delfc said nothing of the unreachable lines (a rule Delf could have). The fix,
  the next node read before the node is freed, the last one known before it is: `dev64`
  `c5ad900`, here `3f0ea9c`, delfc's output equal to `dev64`'s but the marker. **All four fixed
  builds pass all 72, Win32 and Win64.** Also seen: `InvalidateFile` leaves freed statements'
  addresses in `fInvalidatedStatements` and in others' inheritance lists, compared but never read
  (*Accidentally not breaking* A3). Five units of 106 in Delf, 4.1% of the original lines.

### Handover (22 Nov 2026)

The user moved to another Claude account (*"i will need to change to a new claude acct to cont
working ... pls prepare everything to hand over to it"*). Where everything stands, DelfCpp
included (next unit suggested: `CharUtils`; the PRs; the tests), is in the Delf repo's
`docs/handover-2026-11-22.md`, with the standing rules and every memory note copied in full; the
day's work as a transcript in Delf's `docs/milestones/2026-11-22-delfcpp-unit5-delfnav`. This
chapter goes on from here.
