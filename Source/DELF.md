# Dev-C++ units in Delf

Some of Dev-C++'s units are written in **Delf**, Delphi with a stricter type system. delfc
translates a `.delf` file into the plain Delphi `.pas` beside it, and that `.pas` is what
Delphi compiles. Both are committed, so Dev-C++ builds without delfc.

**Edit the `.delf`, not the `.pas`.** The `.pas` is delfc's output.

## How the build uses it

`devcpp.dproj` runs `DelfUnits.cmd` before each build. With the environment variable
`DELF_POC` set to Delf's `poc` folder (where `python -m delfc` runs), it translates every `.delf`
file under `Source`; without it, it says so and the committed `.pas` files are built.
delfc replaces only a `.pas` it wrote itself, and stops at one edited since.

The journey (every unit, every bug found and what found it, the size as it goes) is logged in
`DELF-JOURNEY.md` at the top of the repository.

## The units

| Unit | Delf | What the rewrite changed and found |
|---|---|---|
| `VCL\ClassBrowsing\IntList` | `IntList.delf` | See the notes at the top of `IntList.delf`. In short: the exported `int64 = integer` alias is gone (it turned every user's `Int64` into a 32-bit `Integer`); a dynamic array replaces `ReallocMem` and pointer casts; `Error` uses `ReturnAddress`, not x86 assembler that reads the wrong place on Win64; `Find` is a real binary search again; `Add` covers every `TDuplicates` value with a `match`. |

### Checked how

- **IntList**: a differential test ran 1,200,000 seeded random operations (add, delete, insert,
  exchange, sort, find, index, objects, out-of-range reads; sorted and unsorted; every
  `TDuplicates`) on the original and the Delf version, comparing every result, exception and
  the whole contents after each step: identical on Win32 and Win64, 2,655,925,190 checks. On
  Win64 the original crashed with an access violation 97,132 times where it should have
  raised `EStringListError` (its assembler); the Delf version raised it. Dev-C++ then built
  for Win32 and Win64, and the 64-bit build's class browser showed the right classes and
  members for a file of nested `#if` / `#elif` / `#else` blocks.

## Notes for the units to come

- **Delf scopes the enumerations a `.delf` unit declares** (`{$SCOPEDENUMS ON}` in the output).
  Plain Delphi units that use their values unqualified must qualify them: `EditorList`'s
  `TLayoutShowType` is used as `lstLeft` in `Tests.pas`.
- **`CppPreprocessor`'s `#if` arithmetic** is now in a real `Int64` (no longer the alias), but it
  still reads operands with `StrToIntDef`, a 32-bit `Integer`: values past 2^31 read as 0. That
  is for its own rewrite (`StrToInt64Def`).
