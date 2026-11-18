"""dev64: IntList's bugs fixed in plain Delphi, as found by its Delf rewrite (delfcpp-units 2797fce).
Keeps the file's bytes (latin-1) and line endings.  usage: dev64_intlist.py <IntList.pas>"""
import re, sys

p = sys.argv[1]
t = open(p, "rb").read().decode("latin-1")
nl = "\r\n" if "\r\n" in t else "\n"

def once(old, new):
    global t
    old, new = old.replace("\n", nl), new.replace("\n", nl)
    assert t.count(old) == 1, old[:60]
    t = t.replace(old, new)

# 1. The exported alias that made every user's Int64 a 32-bit Integer
once("""  // we don't work with int64, so make a typedef...
  int64 = integer;

""", "")
once("Temp := Item1^.FInt; // was Integer(...): harmless, int64 is declared as integer above",
     "Temp := Item1^.FInt;")
t, n = re.subn(r"(?i)\bint64\b", "Integer", t)
print("int64 -> Integer:", n)

# 2. Error: the caller's address from ReturnAddress; the x86 [EBP+4] reads the wrong place on Win64
once("""procedure TIntList.Error(const Msg: String; Data: Integer);

  function ReturnAddr: Pointer;
  asm
          MOV     EAX,[EBP+4]
  end;

begin
  raise EStringListError.CreateFmt(Msg, [Data])at ReturnAddr;
end;""", """procedure TIntList.Error(const Msg: String; Data: Integer);
begin
  // ReturnAddress, not x86 assembler ([EBP+4]), which reads the wrong place on Win64:
  // there, every list error was an access violation
  raise EStringListError.CreateFmt(Msg, [Data]) at ReturnAddress;
end;""")

# 3. Find: a binary search moves past the middle on a miss, not one place
once("""    if Flist^[I].FInt < S then
      L := L + 1""", """    if Flist^[I].FInt < S then
      L := I + 1 // was L + 1: right answers, but one place at a time""")

# 4. Add: every TDuplicates value stated, as Delf's match requires
once("""      dupIgnore: Exit;
      dupError: Error(SDuplicateInt, 0);
    end;""", """      dupIgnore: Exit;
      dupError: Error(SDuplicateInt, 0);
      dupAccept: ; // inserted beside the first
    end;""")

open(p, "wb").write(t.encode("latin-1"))
print("ok")
