# DelfCpp: the journey, journal 2

The second volume of DelfCpp's journal (the user, 22 Nov 2026: *"start a new journal 2"*).
[Journal 1, `DELF-JOURNEY.md`](DELF-JOURNEY.md), holds the start: the principles, the branches,
units 1-4 (IntList, EditorList, Instances, CppTokenizer), errors 1-32, the tests, the fixes,
lessons, takeaways, the upstream PRs and its log to 20 Nov. Its principles still hold, and the
numbering carries on: units from 5, errors from 33, the tally from journal 1's.

**One of two journals** still (the user, 20 Nov): this is DelfCpp's, the Dev-C++ fork. Delf's
own process record is the Delf repo's `docs/lifetime-diagnostics-record.md`. A milestone goes in
whichever it belongs to; one that is both goes in both, each pointing at the other.

## Size

Continuing journal 1's table (`delfcpp-tools/size.py . HEAD`).

| When | Own `.pas` | Own `.delf` | Own `.dfm` | Own `.dpr`+`.inc` | Tools (all kinds) | Bundled (all kinds) |
|---|---|---|---|---|---|---|
| `delfcpp-units` after StatementList (CppTokenizer included) | 106 files, 58,112 lines¹ | 5 files, 2,290 lines | 68 files, 45,690 lines | 22 `.dpr` (204) + 1 `.inc` (1,326)² | unchanged | unchanged |

¹ Includes the generated `.pas` of each Delf unit. Units in Delf so far: **5 of 106** (2,299
of ~56,750 original lines, 4.1%).
² `size.py` counts `.dpr` and `.inc` apart.

## Files attacked

| # | Unit | Lines (before → `.delf`) | `delfcpp-units` | `dev64` | Checked by |
|---|---|---|---|---|---|
| 5 | `VCL\ClassBrowsing\StatementList` | 231 → 238 | `a7d259a` (pass 1), `3f0ea9c` (fix) | `c5ad900` | Pass 1 the door: delfc's output = the original byte for byte, but the marker. Tests first (`15f4eea`, `d661eec`): 10 DUnitX tests, among them 200,000 random operations against a `TList` with the links walked both ways; the same source on the original, `dev64` and Delf, Win32 + Win64 |

## Errors found

Same columns and "Found by" as journal 1.

| # | Where | The bug | Effect | Found by | Fixed in |
|---|---|---|---|---|---|
| 33 | `StatementList.DeleteFromTo` | A `break` straight after the first node's deletion, before the loop's `if Node = ToNode` test: it deletes `FromNode` alone, whatever `ToNode` is. The lines after the `break` are unreachable, and would read the freed node's `NextNode` if the `break` were taken out | Latent: nothing in Dev-C++ calls it (the parser deletes node by node). A caller would get a list with the rest of the range still in it | Claude, reading the unit; the tests confirmed it (the original deletes one node of a range of 3 or 6). delfc said nothing: Delf has no rule for statements after an unconditional `break` | `3f0ea9c`, `c5ad900` |

**Observed, not counted (22 Nov, StatementList):** `CppParser.InvalidateFile` adds a class
statement to `fInvalidatedStatements` and then deletes its node; the list owns its statements, so
the statement is disposed and `fInvalidatedStatements` holds its address. Other statements'
`_InheritanceList`s still point at it too. `ReProcessInheritance` only compares those addresses
(to find the files to reparse), never reads through them, so nothing breaks; but valid statements
carry pointers to freed ones until the reparse. A lifetime story Delf's diagnostics are about.

**Tally:** journal 1's (Claude 23, dcc64 2, test 5, running it 1, Rust 1, Delf 0), plus
Claude 1 here: **Claude 24**, the rest unchanged.

## Log

- **22 Nov 2026, StatementList, the fifth unit.** Chosen from the units with no form and few of
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
  (above, "Observed"). Five units of 106 in Delf, 4.1% of the original lines.
