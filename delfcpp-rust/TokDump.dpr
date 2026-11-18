program TokDump;

{ TokDump <root> <list> <out>: the Delphi side of delfcpp-rust's comparison. The same output as
  the Rust tokdump (src\main.rs): "=== path", then "line<TAB>text" per token, UTF-8; files read
  as Latin-1; an exception ends a file with "!error". Built against one version's CppTokenizer
  by unit path (compare.ps1). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, CppTokenizer;

function Escape(const S: string): string;
var
  Ch: Char;
  B: TStringBuilder;
begin
  B := TStringBuilder.Create;
  try
    for Ch in S do
      case Ch of
        '\': B.Append('\\');
        #9: B.Append('\t');
        #13: B.Append('\r');
        #10: B.Append('\n');
      else
        B.Append(Ch);
      end;
    Result := B.ToString;
  finally
    B.Free;
  end;
end;

var
  Root, Name, Text: string;
  Names: TArray<string>;
  Bytes: TBytes;
  Dump: TStringBuilder;
  Tok: TCppTokenizer;
  I, Files: Integer;
begin
  if ParamCount <> 3 then begin
    Writeln(ErrOutput, 'usage: TokDump <root> <list> <out>');
    Halt(2);
  end;
  Root := ParamStr(1);
  Names := System.IOUtils.TFile.ReadAllLines(ParamStr(2));
  Dump := TStringBuilder.Create;
  Tok := TCppTokenizer.Create(nil);
  Files := 0;
  try
    for Name in Names do begin
      if Trim(Name) = '' then
        Continue;
      Bytes := System.IOUtils.TFile.ReadAllBytes(Root + '/' + Trim(Name));
      SetLength(Text, Length(Bytes));
      for I := 0 to High(Bytes) do
        Text[I + 1] := Char(Bytes[I]);
      Dump.Append('=== ').Append(Trim(Name)).Append(#10);
      try
        Tok.TokenizeBuffer(PChar(Text));
        for I := 0 to Tok.Tokens.Count - 1 do
          Dump.Append(Tok[I]^.Line).Append(#9).Append(Escape(Tok[I]^.Text)).Append(#10);
      except
        on Exception do begin
          for I := 0 to Tok.Tokens.Count - 1 do
            Dump.Append(Tok[I]^.Line).Append(#9).Append(Escape(Tok[I]^.Text)).Append(#10);
          Dump.Append('!error'#10);
        end;
      end;
      Inc(Files);
    end;
    System.IOUtils.TFile.WriteAllText(ParamStr(3), Dump.ToString, TUTF8Encoding.Create(False));
  finally
    Tok.Free;
    Dump.Free;
  end;
  Writeln(ErrOutput, 'TokDump (Delphi): ', Files, ' files');
end.
