program DelfCppTests;

{ DelfCpp's tests: one source for every version of a unit. run-tests.cmd builds this program
  three times, with the unit path pointing at the original (pre-fix) units, at dev64's plain
  Delphi, and at delf-units' delfc output, for Win32 and Win64. A test sees only the unit's
  interface, so the same assertions judge all three. Regression tests (category "Regression")
  are expected to fail on the original: that is the bug they pin. }

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,
  Test.CppTokenizer in 'Test.CppTokenizer.pas',
  Test.CppParser in 'Test.CppParser.pas',
  Test.IntList in 'Test.IntList.pas',
  Test.Instances in 'Test.Instances.pas',
  Test.Utils in 'Test.Utils.pas',
  Test.EditorList in 'Test.EditorList.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
begin
  try
    TDUnitX.CheckCommandLine;
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.FailsOnNoAsserts := True;
    Runner.AddLogger(TDUnitXConsoleLogger.Create(True));
    Results := Runner.Execute;
    if not Results.AllPassed then
      System.ExitCode := 1;
  except
    on E: Exception do begin
      Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := 2;
    end;
  end;
end.
