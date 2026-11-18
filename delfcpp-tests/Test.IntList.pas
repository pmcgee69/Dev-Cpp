unit Test.IntList;

{ IntList: a sorted or unsorted list of integers with objects; used by the class browser
  (CppParser's skip list, CppPreprocessor's #if branch stack).

  Category "Characterization": what it did before any change; every version must pass.
  Category "Regression": DELF-JOURNEY.md errors 8-11. The original fails these, some only on
  Win64 (error 8: its Error read the caller's address with x86 assembler). }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TIntListTests = class
  public
    [Test] [Category('Characterization')]
    procedure UnsortedKeepsOrder;
    [Test] [Category('Characterization')]
    procedure SortedAddsInOrder;
    [Test] [Category('Characterization')]
    [TestCase('dupIgnore', '0,2')]
    [TestCase('dupAccept', '1,3')]
    procedure Duplicates(const Rule, ExpectedCount: Integer);
    [Test] [Category('Characterization')]
    procedure DuplicateErrorRaises;
    [Test] [Category('Characterization')]
    procedure FindAndIndexOf;
    [Test] [Category('Characterization')]
    procedure InsertDeleteExchangeObjects;
    [Test] [Category('Characterization')]
    procedure StreamRoundTrip;

    // Regression
    [Test] [Category('Regression')]
    procedure BadIndexRaisesListError;
    [Test] [Category('Regression')]
    procedure Int64IsStill64Bits;
    [Test] [Category('Regression')]
    procedure ShortStreamRaises;
    [Test] [Category('Regression')]
    procedure FindIsABinarySearch;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.Diagnostics, IntList;

function Items(L: TIntList): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to L.Count - 1 do
    Result := Result + IntToStr(L[I]) + ' ';
  Result := Result.Trim;
end;

procedure TIntListTests.UnsortedKeepsOrder;
var
  L: TIntList;
begin
  L := TIntList.Create;
  try
    L.Add(5); L.Add(1); L.Add(3); L.Add(1);
    Assert.AreEqual('5 1 3 1', Items(L));
  finally
    L.Free;
  end;
end;

procedure TIntListTests.SortedAddsInOrder;
var
  L: TIntList;
begin
  L := TIntList.Create;
  try
    L.Add(5); L.Add(1); L.Add(3);
    L.Sorted := True; // sorts what is there
    Assert.AreEqual('1 3 5', Items(L));
    L.Add(4); L.Add(0); L.Add(9);
    Assert.AreEqual('0 1 3 4 5 9', Items(L));
  finally
    L.Free;
  end;
end;

procedure TIntListTests.Duplicates(const Rule, ExpectedCount: Integer);
var
  L: TIntList;
begin
  L := TIntList.Create;
  try
    L.Duplicates := TDuplicates(Rule);
    L.Sorted := True;
    L.Add(2); L.Add(7); L.Add(2);
    Assert.AreEqual(ExpectedCount, L.Count);
  finally
    L.Free;
  end;
end;

procedure TIntListTests.DuplicateErrorRaises;
var
  L: TIntList;
begin
  L := TIntList.Create;
  try
    L.Duplicates := dupError;
    L.Sorted := True;
    L.Add(2);
    Assert.WillRaise(procedure begin L.Add(2) end, EStringListError);
  finally
    L.Free;
  end;
end;

procedure TIntListTests.FindAndIndexOf;
var
  L: TIntList;
  I: Integer;
begin
  L := TIntList.Create;
  try
    L.Sorted := True;
    for I in [10, 20, 30, 40] do
      L.Add(I);
    Assert.IsTrue(L.Find(30, I));
    Assert.AreEqual(2, I);
    Assert.IsFalse(L.Find(25, I));
    Assert.AreEqual(2, I, 'where 25 would go');
    Assert.IsFalse(L.Find(99, I));
    Assert.AreEqual(4, I, 'past the end');
    Assert.AreEqual(1, L.IndexOf(20));
    Assert.AreEqual(-1, L.IndexOf(21));
  finally
    L.Free;
  end;
end;

procedure TIntListTests.InsertDeleteExchangeObjects;
var
  L: TIntList;
  A, B: TObject;
begin
  L := TIntList.Create;
  A := TObject.Create;
  B := TObject.Create;
  try
    L.AddObject(1, A);
    L.AddObject(2, B);
    L.Insert(1, 9);
    Assert.AreEqual('1 9 2', Items(L));
    L.Exchange(0, 2);
    Assert.AreEqual('2 9 1', Items(L));
    Assert.AreSame(B, L.Objects[0], 'objects move with their integers');
    Assert.AreSame(A, L.Objects[2]);
    L.Delete(1);
    Assert.AreEqual('2 1', Items(L));
    L.Clear;
    Assert.AreEqual(0, L.Count);
  finally
    L.Free;
    A.Free;
    B.Free;
  end;
end;

procedure TIntListTests.StreamRoundTrip;
var
  L, M: TIntList;
  S: TMemoryStream;
begin
  L := TIntList.Create;
  M := TIntList.Create;
  S := TMemoryStream.Create;
  try
    L.Add(3); L.Add(-1); L.Add(MaxInt);
    L.SaveToStream(S);
    S.Position := 0;
    M.LoadFromStream(S);
    Assert.AreEqual(Items(L), Items(M));
  finally
    L.Free;
    M.Free;
    S.Free;
  end;
end;

procedure TIntListTests.BadIndexRaisesListError;
var
  L: TIntList;
begin
  // Error 8: the original's Error found its caller with x86 assembler; on Win64 every list
  // error was an access violation instead of EStringListError
  L := TIntList.Create;
  try
    L.Add(1);
    Assert.WillRaise(procedure begin L[5] end, EStringListError);
    Assert.WillRaise(procedure begin L.Delete(-1) end, EStringListError);
  finally
    L.Free;
  end;
end;

procedure TIntListTests.Int64IsStill64Bits;
begin
  // Error 10: the original exported "int64 = integer", so in any unit using IntList (this one)
  // Int64 meant a 32-bit Integer
  Assert.AreEqual(8, Integer(SizeOf(Int64)));
end;

procedure TIntListTests.ShortStreamRaises;
var
  L: TIntList;
  S: TMemoryStream;
  N: Integer;
begin
  // Error 11: a count of 3 but one value: the original filled the rest with junk, silently
  S := TMemoryStream.Create;
  L := TIntList.Create;
  try
    N := 3; S.WriteBuffer(N, SizeOf(N));
    N := 42; S.WriteBuffer(N, SizeOf(N));
    S.Position := 0;
    Assert.WillRaise(procedure begin L.LoadFromStream(S) end, EReadError);
  finally
    L.Free;
    S.Free;
  end;
end;

procedure TIntListTests.FindIsABinarySearch;
const
  Size = 1000000;
  Lookups = 1000;
var
  L: TIntList;
  I, Index: Integer;
  Clock: TStopwatch;
begin
  // Error 9: on a miss the original moved one place (L := L + 1), so Find took linear time:
  // right answers, slowly. A value past the end is the worst case: about Size steps a lookup.
  L := TIntList.Create;
  try
    for I := 0 to Size - 1 do
      L.Add(I * 2); // added in order, unsorted, then marked sorted (no sort needed)
    L.Sorted := True;
    Clock := TStopwatch.StartNew;
    for I := 1 to Lookups do
      L.Find(Size * 2 + I, Index);
    Clock.Stop;
    Assert.AreEqual(Size, Index, 'the place past the end');
    Assert.IsTrue(Clock.ElapsedMilliseconds < 200,
      Format('%d lookups took %d ms: a linear search', [Lookups, Clock.ElapsedMilliseconds]));
  finally
    L.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TIntListTests);

end.
