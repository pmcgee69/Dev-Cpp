# DelfCpp: the journey, journal 2

The second volume of DelfCpp's journal (the user, 22 Nov 2026: *"start a new journal 2"*).
[Journal 1, `DELF-JOURNEY.md`](DELF-JOURNEY.md), holds the start: the principles, the branches,
units 1-4 (IntList, EditorList, Instances, CppTokenizer), errors 1-32, the tests, the fixes,
lessons, takeaways, the upstream PRs and its log to 20 Nov. Its principles still hold, and the
numbering carries on: units from 5, errors from 33, the tally from journal 1's.

**One of two journals** still (the user, 20 Nov): this is DelfCpp's, the Dev-C++ fork. Delf's
own process record is the Delf repo's `docs/lifetime-diagnostics-record.md`. A milestone goes in
whichever it belongs to; one that is both goes in both, each pointing at the other.

**A series** (the user, 22 Nov: *"I think this whole thing could be an ongoing series of videos.
106 units. So new chapter for the journal here."*). From here the journal runs in **chapters, one
per unit**, numbered by the unit (Chapter 5 is the fifth unit), each one an episode: what the
unit is, the tests, what reading it found, pass 1, the fixes, what it says about Delf. The
running tables stay at the top.

## Accidentally not breaking

The user, 22 Nov: *"I want to keep particular record of things like these that are only
accidentally not breaking problems. We'll replace them later with correct delf ideas."* Code that
works today by luck, not by design: an unwritten value that happens to be right, a read that
happens to land on something harmless, a pointer to freed memory that happens never to be read
through. Each stays here until a Delf idea makes the right version the natural one; the last
column is for that idea, **open** until then (Claude's first thoughts marked as such).

| # | Where | Why it works | What would break it | Ch. / error | Delf idea (later) |
|---|---|---|---|---|---|
| A1 | `CppTokenizer.GetForInit` | A `String` function never assigns `Result`; Delphi hands the caller `''`, which is what it needs | A caller that passes a non-empty `Result` slot (Delphi's string results are hidden `var` parameters, so the old value can come back) | journal 1, error 25 (found by Rust) | Open. First thought: every path assigns `Result`, checked by delfc |
| A2 | `CppTokenizer.SimplifyArgs` | Reads `Output[Length + 1]`, one past the end; Delphi's strings end in `#0`, which counts as blank | Range checks on (raises); a `TArray<Char>` or slice instead of a string (no `#0` there) | journal 1, error 26 (Rust) | Open. First thought: indexing that can't step past the end, or says so in its type |
| A3 | `CppParser.InvalidateFile`, `ReProcessInheritance` | A deleted class's statement is disposed (the list owns it), but its address stays in `fInvalidatedStatements` and in other statements' `_InheritanceList`s until the reparse. Only compared, never read through | Any code that reads through one of those pointers before the reparse (a class browser hover, a debug dump), or a new statement allocated at the same address and compared as if it were the old one | Ch. 5 | Open. A lifetime question: what may still point at a statement when its list frees it |

Related but not the same kind: journal 1's **dormant** errors (13, 16-20, 24) and error 33 here are
bugs that bite on rarer input or a first caller; they're in the errors tables.

## Running tables

### Size

Continuing journal 1's table (`delfcpp-tools/size.py . HEAD`).

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

Same columns and "Found by" as journal 1.

| # | Where | The bug | Effect | Found by | Fixed in |
|---|---|---|---|---|---|
| 33 | `StatementList.DeleteFromTo` | A `break` straight after the first node's deletion, before the loop's `if Node = ToNode` test: it deletes `FromNode` alone, whatever `ToNode` is. The lines after the `break` are unreachable, and would read the freed node's `NextNode` if the `break` were taken out | Latent: nothing in Dev-C++ calls it (the parser deletes node by node). A caller would get a list with the rest of the range still in it | Claude, reading the unit; the tests confirmed it (the original deletes one node of a range of 3 or 6). delfc said nothing: Delf has no rule for statements after an unconditional `break` | `3f0ea9c`, `c5ad900` |

**Observed, not counted:** see *Accidentally not breaking* A3, above.

**Tally:** journal 1's (Claude 23, dcc64 2, test 5, running it 1, Rust 1, Delf 0), plus
Claude 1 here: **Claude 24**, the rest unchanged.

## Chapters

### Chapter 5: StatementList (22 Nov 2026)

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
