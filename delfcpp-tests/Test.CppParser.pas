unit Test.CppParser;

{ The class browser's chain, preprocessor -> tokenizer -> parser, run on upstream's own parser
  corpus (Source\Tests\Parser, with the checks listed in Source\Tests\Document\manual.tex), as
  the app runs it (main.pas, UpdateClassBrowsing), without a window.

  Category "Upstream": a check from upstream's manual test plan, made an assertion.
  Category "Characterization": every statement the parser finds in each corpus file (kind, name,
  type, args, line, parent), compared with golden\<file>.txt, recorded from upstream master.
  Set DELFCPP_WRITE_GOLDEN=1 to write the golden files instead of comparing (do that only with
  the original units). }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TCppParserTests = class
  public
    [Test] [Category('Upstream')]
    procedure PreprocessorCorrectVariablesOnly;

    [Test] [Category('Characterization')]
    [TestCase('Code', 'Code.cpp')]
    [TestCase('Function', 'Function.cpp')]
    [TestCase('Include', 'Include.cpp')]
    [TestCase('OperatorTest', 'OperatorTest.cpp')]
    [TestCase('Preprocessor', 'Preprocessor.cpp')]
    [TestCase('SimpleClass', 'SimpleClass.cpp')]
    [TestCase('Struct', 'Struct.cpp')]
    [TestCase('Typedef', 'Typedef.cpp')]
    [TestCase('Variable', 'Variable.cpp')]
    [TestCase('float3', 'float3.cpp')]
    [TestCase('string', 'string.cpp')]
    [TestCase('stl basic_string.h', 'stl/basic_string.h')]
    [TestCase('stl stl_deque.h', 'stl/stl_deque.h')]
    [TestCase('stl stl_list.h', 'stl/stl_list.h')]
    [TestCase('stl stl_map.h', 'stl/stl_map.h')]
    [TestCase('stl stl_queue.h', 'stl/stl_queue.h')]
    [TestCase('stl stl_stack.h', 'stl/stl_stack.h')]
    [TestCase('stl stl_vector.h', 'stl/stl_vector.h')]
    procedure Statements(const FileName: string);
  end;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils, System.RegularExpressions,
  cbutils, StatementList, CppTokenizer, CppPreprocessor, CppParser;

// The test program sits in delfcpp-tests\out\<version>-win<n>; the corpus is in the checkout
function TestsDir: string;
begin
  Result := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..'));
end;

function CorpusDir: string;
begin
  Result := TPath.GetFullPath(TPath.Combine(TestsDir, '..\Source\Tests\Parser'));
end;

const
  KindNames: array[TStatementKind] of string = ('class', 'function', 'constructor', 'destructor',
    'variable', 'typedef', 'enum', 'preprocessor', 'unknown');

// Parses one corpus file as the app does, and lists what it found, one statement a line
function ParseToText(const FileName: string): TStringList;
var
  Tokenizer: TCppTokenizer;
  Preprocessor: TCppPreprocessor;
  Parser: TCppParser;
  Node: PStatementNode;
  S: PStatement;
  Parent: string;
begin
  Result := TStringList.Create;
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
    Parser.AddHardDefineByLine('#define WIN32 1'); // the corpus is written for Windows' gcc
    Parser.ParseFile(TPath.Combine(CorpusDir, FileName), True);
    Node := Parser.Statements.FirstNode;
    while Assigned(Node) do begin
      S := Node^.Data;
      if Assigned(S^._Parent) then
        Parent := S^._Parent^._Command
      else
        Parent := '';
      Result.Add(Format('%s|%s|%s|%s|%s:%d|parent %s', [KindNames[S^._Kind], S^._Command,
        S^._Type, S^._Args, ExtractFileName(S^._FileName), S^._Line, Parent]));
      Node := Node^.NextNode;
    end;
  finally
    Parser.Free;
    Preprocessor.Free;
    Tokenizer.Free;
  end;
end;

{ TCppParserTests }

procedure TCppParserTests.PreprocessorCorrectVariablesOnly;
var
  Source: string;
  Expected: TStringList;
  Found: TStringList;
  M: TMatch;
  Line, Name: string;
begin
  // manual.tex: "Correctly parse Preprocessor.cpp. Check if all variables are called CorrectXX."
  Source := System.IOUtils.TFile.ReadAllText(TPath.Combine(CorpusDir, 'Preprocessor.cpp'));
  Expected := TStringList.Create;
  Found := TStringList.Create;
  try
    Expected.Sorted := True;
    Expected.Duplicates := dupIgnore;
    for M in TRegEx.Matches(Source, '\bCorrect\d+\b') do
      Expected.Add(M.Value);
    Assert.IsTrue(Expected.Count >= 5, 'the corpus file has its CorrectNN variables');

    Found.Sorted := True;
    Found.Duplicates := dupIgnore;
    for Line in ParseToText('Preprocessor.cpp') do
      if Line.StartsWith('variable|') then begin
        Name := Line.Split(['|'])[1];
        Assert.IsFalse(Name.StartsWith('Incorrect'), 'a branch the preprocessor should drop: ' + Name);
        Found.Add(Name);
      end;
    for Name in Expected do
      Assert.IsTrue(Found.IndexOf(Name) >= 0, 'not parsed: ' + Name);
  finally
    Expected.Free;
    Found.Free;
  end;
end;

procedure TCppParserTests.Statements(const FileName: string);
var
  Got: TStringList;
  Golden: string;
begin
  Golden := TPath.Combine(TestsDir, 'golden\' + ChangeFileExt(FileName.Replace('/', '_'), '.txt'));
  Got := ParseToText(FileName);
  try
    if GetEnvironmentVariable('DELFCPP_WRITE_GOLDEN') = '1' then begin
      ForceDirectories(ExtractFilePath(Golden));
      Got.SaveToFile(Golden, TEncoding.UTF8);
      Assert.Pass('golden written: ' + Golden);
    end;
    Assert.IsTrue(FileExists(Golden), 'no golden file: ' + Golden);
    Assert.AreEqual(System.IOUtils.TFile.ReadAllText(Golden, TEncoding.UTF8).Trim, Got.Text.Trim);
  finally
    Got.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCppParserTests);

end.
