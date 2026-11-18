unit AnsiStrings;

{ Stand-in for Delphi's System.AnsiStrings under WebAssembly: cbutils calls StrComp and StrIComp
  on PAnsiChar. FPC has both in SysUtils. }

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

function StrComp(const Str1, Str2: PAnsiChar): Integer;
function StrIComp(const Str1, Str2: PAnsiChar): Integer;

implementation

uses
  SysUtils;

function StrComp(const Str1, Str2: PAnsiChar): Integer;
begin
  Result := SysUtils.StrComp(Str1, Str2);
end;

function StrIComp(const Str1, Str2: PAnsiChar): Integer;
begin
  Result := SysUtils.StrIComp(Str1, Str2);
end;

end.
