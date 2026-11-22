unit Test.StatementList;

{ StatementList: the class browser's doubly linked list of parsed statements (CppParser's
  fStatementList), with its nodes and, when it owns them, its statements disposed by hand.

  Category "Characterization": what it did before any change; every version must pass. Among
  them a differential run: 200,000 random operations against a plain TList, with the links
  walked both ways as it goes.
  Category "Regression": DELF-JOURNEY.md error 33. DeleteFromTo deleted only its first node
  (a `break` before the loop's test), so the original fails these. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TStatementListTests = class
  public
    [Test] [Category('Characterization')]
    procedure AddKeepsOrder;
    [Test] [Category('Characterization')]
    procedure EmptyList;
    [Test] [Category('Characterization')]
    procedure DeleteFirstMiddleLast;
    [Test] [Category('Characterization')]
    procedure DeleteByData;
    [Test] [Category('Characterization')]
    procedure ClearEmpties;
    [Test] [Category('Characterization')]
    procedure OwnedStatementsAreDisposed;
    [Test] [Category('Characterization')]
    procedure RandomOperationsAgainstAList;

    // Regression
    [Test] [Category('Regression')]
    procedure DeleteFromToDeletesTheRange;
    [Test] [Category('Regression')]
    procedure DeleteFromToNilGoesToTheEnd;
    [Test] [Category('Regression')]
    procedure DeleteFromToEverything;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.Generics.Collections, CBUtils, StatementList;

type
  // an inheritance list that counts its own freeing
  TCountedList = class(TList)
  public
    destructor Destroy; override;
  end;

var
  ListsFreed: Integer;

destructor TCountedList.Destroy;
begin
  Inc(ListsFreed);
  inherited;
end;

function NewStatement(const Name: string): PStatement;
begin
  New(Result);
  Result^ := Default(TStatement);
  Result^._Command := Name;
end;

// the names, first to last, by the forward links
function Names(L: TStatementList): string;
var
  Node: PStatementNode;
begin
  Result := '';
  Node := L.FirstNode;
  while Assigned(Node) do begin
    Result := Result + Node^.Data^._Command + ' ';
    Node := Node^.NextNode;
  end;
  Result := Result.Trim;
end;

// the names, first to last, by the backward links
function NamesBack(L: TStatementList): string;
var
  Node: PStatementNode;
begin
  Result := '';
  Node := L.LastNode;
  while Assigned(Node) do begin
    Result := (Node^.Data^._Command + ' ' + Result);
    Node := Node^.PrevNode;
  end;
  Result := Result.Trim;
end;

function NodeAt(L: TStatementList; Index: Integer): PStatementNode;
begin
  Result := L.FirstNode;
  while Index > 0 do begin
    Result := Result^.NextNode;
    Dec(Index);
  end;
end;

function Make(const S: string): TStatementList;
begin
  Result := TStatementList.Create;
  for var N in S.Split([' ']) do
    Result.Add(NewStatement(N));
end;

procedure CheckBothWays(L: TStatementList; const Expected: string; Count: Integer);
begin
  Assert.AreEqual(Expected, Names(L), 'forward');
  Assert.AreEqual(Expected, NamesBack(L), 'backward');
  Assert.AreEqual(Count, L.Count, 'count');
end;

procedure TStatementListTests.AddKeepsOrder;
var
  L: TStatementList;
begin
  L := TStatementList.Create;
  try
    Assert.AreEqual(1, L.Add(NewStatement('a')));
    Assert.AreEqual(2, L.Add(NewStatement('b')));
    Assert.AreEqual(3, L.Add(NewStatement('c')));
    CheckBothWays(L, 'a b c', 3);
    Assert.AreEqual('a', L.FirstStatement^._Command);
    Assert.AreEqual('c', L.LastStatement^._Command);
  finally
    L.Free;
  end;
end;

procedure TStatementListTests.EmptyList;
var
  L: TStatementList;
begin
  L := TStatementList.Create;
  try
    Assert.IsTrue(L.FirstStatement = nil);
    Assert.IsTrue(L.LastStatement = nil);
    Assert.AreEqual(0, L.DeleteFirst);
    Assert.AreEqual(0, L.DeleteLast);
    Assert.AreEqual(0, L.Delete(PStatementNode(nil)));
    CheckBothWays(L, '', 0);
  finally
    L.Free;
  end;
end;

procedure TStatementListTests.DeleteFirstMiddleLast;
var
  L: TStatementList;
begin
  L := Make('a b c d e');
  try
    Assert.AreEqual(4, L.DeleteFirst);
    CheckBothWays(L, 'b c d e', 4);
    Assert.AreEqual(3, L.DeleteLast);
    CheckBothWays(L, 'b c d', 3);
    Assert.AreEqual(2, L.Delete(NodeAt(L, 1)));
    CheckBothWays(L, 'b d', 2);
    L.DeleteFirst;
    L.DeleteFirst;
    CheckBothWays(L, '', 0);
    Assert.IsTrue(L.FirstStatement = nil);
  finally
    L.Free;
  end;
end;

procedure TStatementListTests.DeleteByData;
var
  L: TStatementList;
  Stranger: PStatement;
begin
  L := Make('a b c');
  try
    Assert.AreEqual(2, L.Delete(NodeAt(L, 1)^.Data));
    CheckBothWays(L, 'a c', 2);
    Stranger := NewStatement('x');
    try
      Assert.AreEqual(2, L.Delete(Stranger)); // not in the list: nothing happens
      CheckBothWays(L, 'a c', 2);
    finally
      Dispose(Stranger);
    end;
  finally
    L.Free;
  end;
end;

procedure TStatementListTests.ClearEmpties;
var
  L: TStatementList;
begin
  L := Make('a b c');
  try
    L.Clear;
    CheckBothWays(L, '', 0);
    L.Add(NewStatement('d'));
    CheckBothWays(L, 'd', 1);
  finally
    L.Free;
  end;
end;

procedure TStatementListTests.OwnedStatementsAreDisposed;
var
  L: TStatementList;
  S: PStatement;
begin
  ListsFreed := 0;
  L := TStatementList.Create; // owns its statements by default
  try
    for var I := 1 to 4 do begin
      S := NewStatement(IntToStr(I));
      S^._InheritanceList := TCountedList.Create;
      L.Add(S);
    end;
    L.DeleteFirst;
    Assert.AreEqual(1, ListsFreed, 'DeleteFirst');
    L.Delete(L.LastStatement);
    Assert.AreEqual(2, ListsFreed, 'Delete by data');
  finally
    L.Free;
  end;
  Assert.AreEqual(4, ListsFreed, 'Free');
end;

procedure TStatementListTests.RandomOperationsAgainstAList;
const
  Ops = 200000;
var
  L: TStatementList;
  Ref: TList<PStatement>;
  Seq: Integer;

  procedure Gone(S: PStatement);
  begin
    Ref.Remove(S);
    Dispose(S);
  end;

  function RefNames: string;
  begin
    Result := '';
    for var S in Ref do
      Result := Result + S^._Command + ' ';
    Result := Result.Trim;
  end;

begin
  RandSeed := 20261122;
  L := TStatementList.Create;
  Ref := TList<PStatement>.Create;
  try
    L.OwnsObjects := False; // the test disposes, so the list and the reference stay comparable
    Seq := 0;
    for var I := 1 to Ops do begin
      var R := Random(100);
      var Got: Integer;
      if (R < 40) or (Ref.Count = 0) then begin
        Inc(Seq);
        var S := NewStatement(IntToStr(Seq));
        Got := L.Add(S);
        Ref.Add(S);
      end else if R < 55 then begin
        var S := Ref.First;
        Got := L.DeleteFirst;
        Gone(S);
      end else if R < 70 then begin
        var S := Ref.Last;
        Got := L.DeleteLast;
        Gone(S);
      end else if R < 85 then begin
        var K := Random(Ref.Count);
        var S := Ref[K];
        Got := L.Delete(NodeAt(L, K));
        Gone(S);
      end else if R < 98 then begin
        var S := Ref[Random(Ref.Count)];
        Got := L.Delete(S);
        Gone(S);
      end else begin
        L.Clear;
        Got := L.Count;
        while Ref.Count > 0 do
          Gone(Ref.Last);
      end;
      var N: Integer := Ref.Count; // NativeInt on Win64
      Assert.AreEqual(N, Got, 'returned count, op ' + IntToStr(I));
      Assert.AreEqual(N, L.Count, 'count, op ' + IntToStr(I));
      if Ref.Count > 0 then begin
        Assert.IsTrue(L.FirstStatement = Ref.First, 'first, op ' + IntToStr(I));
        Assert.IsTrue(L.LastStatement = Ref.Last, 'last, op ' + IntToStr(I));
      end;
      if I mod 97 = 0 then begin
        var E := RefNames;
        Assert.AreEqual(E, Names(L), 'forward, op ' + IntToStr(I));
        Assert.AreEqual(E, NamesBack(L), 'backward, op ' + IntToStr(I));
      end;
    end;
  finally
    L.Free;
    while Ref.Count > 0 do begin
      Dispose(Ref.Last);
      Ref.Delete(Ref.Count - 1);
    end;
    Ref.Free;
  end;
end;

procedure TStatementListTests.DeleteFromToDeletesTheRange;
var
  L: TStatementList;
begin
  L := Make('a b c d e f');
  try
    Assert.AreEqual(3, L.DeleteFromTo(NodeAt(L, 1), NodeAt(L, 3)));
    CheckBothWays(L, 'a e f', 3);
  finally
    L.Free;
  end;
end;

procedure TStatementListTests.DeleteFromToNilGoesToTheEnd;
var
  L: TStatementList;
begin
  L := Make('a b c d e f');
  try
    Assert.AreEqual(3, L.DeleteFromTo(NodeAt(L, 3), nil));
    CheckBothWays(L, 'a b c', 3);
  finally
    L.Free;
  end;
end;

procedure TStatementListTests.DeleteFromToEverything;
var
  L: TStatementList;
begin
  L := Make('a b c');
  try
    Assert.AreEqual(0, L.DeleteFromTo(L.FirstNode, L.LastNode));
    CheckBothWays(L, '', 0);
  finally
    L.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TStatementListTests);

end.
