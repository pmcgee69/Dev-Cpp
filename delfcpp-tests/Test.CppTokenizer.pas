unit Test.CppTokenizer;

{ CppTokenizer: text in, tokens out, so it tests without a window.

  Each text is tokenized with words after its terminating #0 (a "guard"): a tokenizer that reads
  past the end of its text turns the guard into tokens. The expected tokens are written out in
  full, so the same test checks the original, dev64 and Delf versions alike.

  Category "Characterization": what the tokenizer did before any change, on well-formed C++;
  every version must pass. Category "Regression": the bugs found in DelfCpp (DELF-JOURNEY.md,
  errors 21-23); the original fails these. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TCppTokenizerTests = class
  public
    // Characterization: well-formed text
    [Test] [Category('Characterization')]
    [TestCase('declaration', 'int x;|[int] [x] [;]', '|')]
    [TestCase('string literal', 'char* s = "abc"; int y;|[char*] [s] [;] [int] [y] [;]', '|')]
    [TestCase('char literal', 'char c = ''a''; int y;|[char] [c] [;] [int] [y] [;]', '|')]
    [TestCase('escaped quote in a string', 'char* s = "a\"b"; int y;|[char*] [s] [;] [int] [y] [;]', '|')]
    [TestCase('array', 'int a[3];|[int] [a[3]] [;]', '|')]
    [TestCase('two-dimensional array', 'int a[3][4];|[int] [a[3][4]] [;]', '|')]
    [TestCase('function', 'int f(int a, int b) { return a; }|[int] [f] [(int a, int b)] [{] [return] [a] [;] [}]', '|')]
    [TestCase('class', 'class C { public: int v; };|[class] [C] [{] [public] [:] [int] [v] [;] [}] [;]', '|')]
    [TestCase('scope operator', 'std::string s;|[std::string] [s] [;]', '|')]
    [TestCase('comments', 'int /* c */ x; // d'#10'int y;|[int] [x] [;] [int] [y] [;]', '|')]
    [TestCase('UNC path in a string', 'char* p = "\\\\server"; int y;|[char*] [p] [;] [int] [y] [;]', '|')]
    procedure WellFormed(const Text, Expected: string);

    [Test] [Category('Characterization')]
    procedure LineNumbers;

    // Regression: each of these read past the end of the text, or misread an escape
    [Test] [Category('Regression')]
    [TestCase('unterminated string', 'int x; char* s = "abc|[int] [x] [;] [char*] [s]', '|')]
    [TestCase('string ending in a backslash', 'int x; char* s = "abc\|[int] [x] [;] [char*] [s]', '|')]
    [TestCase('unterminated char', 'int x; char c = ''a|[int] [x] [;] [char] [c]', '|')]
    [TestCase('array at the end', 'int x; int a[|[int] [x] [;] [int] [a[]', '|')]
    [TestCase('nested array at the end', 'int x; int a[[|[int] [x] [;] [int] [a[[]', '|')]
    [TestCase('a string of two escaped backslashes', 'char* p = "\\\\"; int after;|[char*] [p] [;] [int] [after] [;]', '|')]
    [TestCase('an escape, then an escaped backslash', 'char* p = "\n\\"; int after;|[char*] [p] [;] [int] [after] [;]', '|')]
    procedure DoesNotReadPastTheEnd(const Text, Expected: string);
  end;

implementation

uses
  System.SysUtils, CppTokenizer;

const
  // After the text's #0: words that are not part of the text. No quotes in it, so a runaway
  // reader stops in it and its words show up as tokens.
  Guard = ' BEYONDTHEEND ; more past the end ;';

function Tokens(const Text: string): string;
var
  Buffer: string;
  T: TCppTokenizer;
  I: Integer;
begin
  Buffer := Text + #0 + Guard + #0;
  T := TCppTokenizer.Create(nil);
  try
    T.TokenizeBuffer(PChar(Buffer));
    Result := '';
    for I := 0 to T.Tokens.Count - 1 do begin
      if I > 0 then
        Result := Result + ' ';
      Result := Result + '[' + T[I]^.Text + ']';
    end;
  finally
    T.Free;
  end;
end;

{ TCppTokenizerTests }

procedure TCppTokenizerTests.WellFormed(const Text, Expected: string);
begin
  Assert.AreEqual(Expected, Tokens(Text));
end;

procedure TCppTokenizerTests.LineNumbers;
var
  Buffer: string;
  T: TCppTokenizer;
begin
  Buffer := 'int x;'#10#10'int y;'#10;
  T := TCppTokenizer.Create(nil);
  try
    T.TokenizeBuffer(PChar(Buffer));
    Assert.AreEqual<Integer>(6, T.Tokens.Count); // <Integer>: on Win64, Count is not the literal's type
    Assert.AreEqual(1, T[0]^.Line, 'int x on line 1');
    Assert.AreEqual(3, T[3]^.Line, 'int y on line 3');
  finally
    T.Free;
  end;
end;

procedure TCppTokenizerTests.DoesNotReadPastTheEnd(const Text, Expected: string);
var
  Got: string;
begin
  Got := Tokens(Text);
  Assert.IsFalse(Got.Contains('BEYOND') or Got.Contains('past'),
    'read past the end of the text: ' + Got);
  Assert.AreEqual(Expected, Got);
end;

initialization
  TDUnitX.RegisterTestFixture(TCppTokenizerTests);

end.
