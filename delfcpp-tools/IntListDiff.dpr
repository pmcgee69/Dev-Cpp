program IntListDiff;

{ Differential test: the original TIntList (IntListOld, from the win64 branch) and the Delf
  version (IntList, delfc's output) get the same seeded random operations, and every result,
  exception and the whole contents are compared after each one. Win32 and Win64. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, IntListOld, IntList;

const
  cSteps = 200000;

var
  Objs: array[0..9] of TObject;
  Checks: System.Int64 = 0; // System.: IntListOld exports "int64 = integer", which wrapped this at 2^31
  OldWin64Crashes: Integer = 0; // the original's Error, x86 assembler on Win64: an access violation

procedure Fail(const What: string; Step: Integer);
begin
  Writeln('MISMATCH at step ', Step, ': ', What);
  Halt(1);
end;

procedure Same(const What: string; A, B: Integer; Step: Integer);
begin
  Inc(Checks);
  if A <> B then
    Fail(Format('%s: old %d, new %d', [What, A, B]), Step);
end;

procedure CompareAll(Old: IntListOld.TIntList; New: IntList.TIntList; Step: Integer);
var
  I: Integer;
begin
  Same('Count', Old.Count, New.Count, Step);
  for I := 0 to Old.Count - 1 do begin
    Same('Integers[' + IntToStr(I) + ']', Old[I], New[I], Step);
    Inc(Checks);
    if Old.Objects[I] <> New.Objects[I] then
      Fail('Objects[' + IntToStr(I) + ']', Step);
  end;
end;

// Runs Op on both lists; both must raise, with the same message, or neither
procedure Both(const OpName: string; Step: Integer; OldOp, NewOp: TProc);
var
  OldMsg, NewMsg: string;
begin
  OldMsg := '';
  NewMsg := '';
  try OldOp() except on E: Exception do OldMsg := E.ClassName + ': ' + E.Message; end;
  try NewOp() except on E: Exception do NewMsg := E.ClassName + ': ' + E.Message; end;
  Inc(Checks);
  if (SizeOf(Pointer) = 8) and OldMsg.StartsWith('EAccessViolation') and NewMsg.StartsWith('EStringListError') then begin
    Inc(OldWin64Crashes);
    Exit;
  end;
  if OldMsg <> NewMsg then
    Fail(Format('%s raised "%s" / "%s"', [OpName, OldMsg, NewMsg]), Step);
end;

procedure Run(Sorted: Boolean; Dup: TDuplicates; Seed: Integer; var Ops: Integer);
var
  Old: IntListOld.TIntList;
  New: IntList.TIntList;
  Step, V, I, J, R1, R2: Integer;
  F1, F2: Boolean;
  O: TObject;
begin
  RandSeed := Seed;
  Old := IntListOld.TIntList.Create;
  New := IntList.TIntList.Create;
  try
    Old.Duplicates := Dup;
    New.Duplicates := Dup;
    Old.Sorted := Sorted;
    New.Sorted := Sorted;
    for Step := 1 to cSteps do begin
      V := Random(200) - 100; // a small range: plenty of duplicates
      case Random(12) of
        0..3: Both('Add', Step,
                procedure begin R1 := Old.Add(V) end,
                procedure begin R2 := New.Add(V) end);
        4: if Old.Count > 0 then begin
             I := Random(Old.Count);
             Both('Delete', Step, procedure begin Old.Delete(I) end,
                                  procedure begin New.Delete(I) end);
           end;
        5: Same('IndexOf', Old.IndexOf(V), New.IndexOf(V), Step);
        6: begin
             F1 := Old.Find(V, R1);
             F2 := New.Find(V, R2);
             if Sorted then begin // Find is a binary search: meaningless on unsorted items
               Same('Find', Ord(F1), Ord(F2), Step);
               Same('Find index', R1, R2, Step);
             end;
           end;
        7: if not Sorted and (Old.Count > 1) then begin
             I := Random(Old.Count);
             J := Random(Old.Count);
             Both('Exchange', Step, procedure begin Old.Exchange(I, J) end,
                                    procedure begin New.Exchange(I, J) end);
           end;
        8: begin // a valid index, or one past either end
             I := Random(Old.Count + 3) - 1;
             Both('Insert', Step, procedure begin Old.Insert(I, V) end,
                                  procedure begin New.Insert(I, V) end);
           end;
        9: if Old.Count > 0 then begin
             I := Random(Old.Count);
             O := Objs[Random(Length(Objs))];
             Both('PutObject', Step, procedure begin Old.Objects[I] := O end,
                                     procedure begin New.Objects[I] := O end);
           end;
        10: if not Sorted and (Random(50) = 0) then begin
              Old.Sort;
              New.Sort;
            end;
        11: begin // out of range reads must raise alike
              I := Random(Old.Count + 4) - 2;
              Both('Get', Step, procedure begin R1 := Old[I] end,
                                procedure begin R2 := New[I] end);
            end;
      end;
      if Random(5000) = 0 then begin
        Old.Clear;
        New.Clear;
      end;
      CompareAll(Old, New, Step);
      Inc(Ops);
    end;
  finally
    Old.Free;
    New.Free;
  end;
end;

var
  K, Ops: Integer;
  Dup: TDuplicates;
begin
  for K := 0 to High(Objs) do
    Objs[K] := TObject.Create;
  Ops := 0;
  for Dup := Low(TDuplicates) to High(TDuplicates) do begin
    Run(False, Dup, 1000 + Ord(Dup), Ops);
    Run(True,  Dup, 2000 + Ord(Dup), Ops);
  end;
  Writeln(SizeOf(Pointer) * 8, '-bit: ', Ops, ' operations, ', Checks, ' checks, old and new identical');
  if OldWin64Crashes > 0 then
    Writeln('  except ', OldWin64Crashes, ' list errors, where the original crashed (access violation) and the Delf version raised EStringListError');
end.
