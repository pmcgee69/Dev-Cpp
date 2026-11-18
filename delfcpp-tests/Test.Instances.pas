unit Test.Instances;

{ Instances.GetSentStructData: the text another Dev-C++ (or any process) sends in WM_COPYDATA.
  Pure: a message in, a string out. (Instances uses main in its implementation, so linking it
  links the app's units; no form is created.)

  Category "Characterization": well-formed messages. Category "Regression": DELF-JOURNEY.md
  error 15: the original read up to a terminator, ignoring cbData. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TInstancesTests = class
  public
    [Test] [Category('Characterization')]
    procedure WellFormed;
    [Test] [Category('Characterization')]
    procedure OtherIdIgnored;
    [Test] [Category('Characterization')]
    procedure NoStructIgnored;
    [Test] [Category('Regression')]
    procedure ReadsOnlyCbData;
  end;

implementation

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, Instances;

// A WM_COPYDATA message for Text, whose buffer holds Text, then Trailer
function Msg(const Text: string; Terminated: Boolean; const Trailer: string;
  var Buffer: string; var Data: TCopyDataStruct; Id: NativeUInt = SENDDATAID): TMessage;
begin
  if Terminated then
    Buffer := Text + #0 + Trailer
  else
    Buffer := Text + Trailer;
  Data.dwData := Id;
  Data.cbData := (Length(Text) + Ord(Terminated)) * SizeOf(Char);
  Data.lpData := PChar(Buffer);
  Result := Default(TMessage);
  Result.Msg := WM_COPYDATA;
  Result.LParam := LPARAM(@Data);
end;

procedure TInstancesTests.WellFormed;
var
  Buffer: string;
  Data: TCopyDataStruct;
begin
  Assert.AreEqual('"devcpp.exe" "a.cpp"',
    GetSentStructData(Msg('"devcpp.exe" "a.cpp"', True, '', Buffer, Data)));
end;

procedure TInstancesTests.OtherIdIgnored;
var
  Buffer: string;
  Data: TCopyDataStruct;
begin
  Assert.AreEqual('', GetSentStructData(Msg('x', True, '', Buffer, Data, SENDDATAID + 1)));
end;

procedure TInstancesTests.NoStructIgnored;
var
  M: TMessage;
begin
  M := Default(TMessage);
  M.Msg := WM_COPYDATA;
  Assert.AreEqual('', GetSentStructData(M));
end;

procedure TInstancesTests.ReadsOnlyCbData;
var
  Buffer: string;
  Data: TCopyDataStruct;
begin
  // No terminator inside cbData, and more text after it in memory: only cbData's text counts
  Assert.AreEqual('"devcpp.exe" "a.cpp"',
    GetSentStructData(Msg('"devcpp.exe" "a.cpp"', False, ' "NOT-SENT.cpp"', Buffer, Data)));
end;

initialization
  TDUnitX.RegisterTestFixture(TInstancesTests);

end.
