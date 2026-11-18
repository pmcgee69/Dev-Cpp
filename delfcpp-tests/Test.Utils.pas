unit Test.Utils;

{ Utils.SetPath: puts a folder at the front of the process's PATH, before the compiler runs.

  Category "Regression": DELF-JOURNEY.md error 19. With UseOriginal = False it read PATH into
  an array of 2,049 characters while telling Windows it held 4,098 (SizeOf): a PATH of 2,049 to
  4,097 characters overran it on the stack, and a longer one appended junk. No caller passes
  False today (dormant), but the function is public. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TUtilsTests = class
  public
    [Test] [Category('Characterization')]
    procedure SetPathShortPath;
    // CrashesOriginal: the original overruns the stack here and the whole test program dies;
    // run-tests.cmd runs these apart for the original, so its other results still count
    [Test] [Category('Regression,CrashesOriginal')]
    [TestCase('PATH of 3,000 characters (overran the stack)', '3000')]
    [TestCase('PATH of 5,000 characters (appended junk)', '5000')]
    procedure SetPathLongPath(const Length: Integer);
  end;

implementation

uses
  Winapi.Windows, System.SysUtils, Utils;

procedure CheckSetPath(const Path: string);
var
  Saved: string;
begin
  Saved := System.SysUtils.GetEnvironmentVariable('PATH');
  try
    Winapi.Windows.SetEnvironmentVariable('PATH', PChar(Path));
    SetPath('C:\NewFolder', False);
    Assert.AreEqual('C:\NewFolder;' + Path, System.SysUtils.GetEnvironmentVariable('PATH'));
  finally
    Winapi.Windows.SetEnvironmentVariable('PATH', PChar(Saved));
  end;
end;

procedure TUtilsTests.SetPathShortPath;
begin
  CheckSetPath('C:\Windows;C:\Windows\System32');
end;

procedure TUtilsTests.SetPathLongPath(const Length: Integer);
var
  Path: string;
begin
  Path := 'C:\Windows';
  while Path.Length < Length do
    Path := Path + ';C:\Some\Long\Folder' + IntToStr(Path.Length);
  CheckSetPath(Path.Substring(0, Length));
end;

initialization
  TDUnitX.RegisterTestFixture(TUtilsTests);

end.
