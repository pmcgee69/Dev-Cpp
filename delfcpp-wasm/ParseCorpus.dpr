program ParseCorpus;

{ The class browser's chain (preprocessor, tokenizer, parser) as a command-line program, for
  WebAssembly: parses each file named on the command line and prints every statement found, in
  delfcpp-tests' golden format (Test.CppParser.pas, ParseToText), one block per file:
    == <file>
    <kind>|<name>|<type>|<args>|<file>:<line>|parent <name>
  Written for both compilers: dcc (Windows) and FPC in delphiunicode mode (wasm32-wasip1).
  No inline variables, no anonymous methods: FPC's Delphi mode lacks the first. }

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$APPTYPE CONSOLE}

uses
  SysUtils, Classes, cbutils, StatementList, CppTokenizer, CppPreprocessor, CppParser;

const
  KindNames: array[TStatementKind] of string = ('class', 'function', 'constructor', 'destructor',
    'variable', 'typedef', 'enum', 'preprocessor', 'unknown');

procedure ParseOne(const FileName: string);
var
  Tokenizer: TCppTokenizer;
  Preprocessor: TCppPreprocessor;
  Parser: TCppParser;
  Node: PStatementNode;
  S: PStatement;
  Parent: string;
begin
  Writeln('== ', ExtractFileName(FileName));
  Tokenizer := TCppTokenizer.Create(nil);
  Preprocessor := TCppPreprocessor.Create(nil);
  Parser := TCppParser.Create(nil);
  try
    Parser.Tokenizer := Tokenizer;
    Parser.Preprocessor := Preprocessor;
    Parser.Enabled := True;
    Parser.ParseLocalHeaders := True;
    Parser.ParseGlobalHeaders := False;
    Parser.ResetDefines;
    Parser.AddHardDefineByLine('#define WIN32 1'); // as delfcpp-tests does
    Parser.ParseFile(FileName, True);
    Node := Parser.Statements.FirstNode;
    while Assigned(Node) do begin
      S := Node^.Data;
      if Assigned(S^._Parent) then
        Parent := S^._Parent^._Command
      else
        Parent := '';
      Writeln(Format('%s|%s|%s|%s|%s:%d|parent %s', [KindNames[S^._Kind], S^._Command,
        S^._Type, S^._Args, ExtractFileName(S^._FileName), S^._Line, Parent]));
      Node := Node^.NextNode;
    end;
  finally
    Parser.Free;
    Preprocessor.Free;
    Tokenizer.Free;
  end;
end;

var
  I: Integer;
begin
  for I := 1 to ParamCount do
    ParseOne(ParamStr(I));
end.
