"""Instances: four bugs fixed, the same text for Instances.delf (delf-units) and Instances.pas (dev64).
Keeps bytes (latin-1) and line endings.  usage: instances_fix.py <file>"""
import sys
p = sys.argv[1]
t = open(p, "rb").read().decode("latin-1")
nl = "\r\n" if "\r\n" in t else "\n"

def once(old, new):
    global t
    old, new = old.replace("\n", nl), new.replace("\n", nl)
    assert t.count(old) == 1, old[:70]
    t = t.replace(old, new)

# 4. WM_COPYDATA comes from any process: take cbData's length, don't trust a terminator
once("""  if Assigned(DataStruct) and (DataStruct^.dwData = SENDDATAID) then
    Result := PChar(DataStruct^.lpData)
  else
    Result := '';""", """  // Any process can send WM_COPYDATA: read cbData's length, not up to a terminator that may be missing
  if Assigned(DataStruct) and (DataStruct^.dwData = SENDDATAID) and Assigned(DataStruct^.lpData) then begin
    SetString(Result, PChar(DataStruct^.lpData), DataStruct^.cbData div SizeOf(Char));
    if Pos(#0, Result) > 0 then
      SetLength(Result, Pos(#0, Result) - 1);
  end else
    Result := '';""")

# 1. Buffer sizes: these APIs count characters; SizeOf(Buffer) is bytes, twice the 512 characters
once("if GetClassName(Handle, Buffer, SizeOf(Buffer)) = 0 then",
     "if GetClassName(Handle, Buffer, Length(Buffer)) = 0 then // characters, not SizeOf's bytes")
once("if GetModuleFileNameEx(WindowProcess, WindowModule, Buffer, SizeOf(Buffer)) = 0 then",
     "if GetModuleFileNameEx(WindowProcess, WindowModule, Buffer, Length(Buffer)) = 0 then")
once("if GetModuleFileName(GetModuleHandle(nil), Buffer, SizeOf(Buffer)) = 0 then",
     "if GetModuleFileName(GetModuleHandle(nil), Buffer, Length(Buffer)) = 0 then // characters")

# 2. The process handle leaked when GetModuleFileNameEx failed
once("""    // Get its module filename
    if GetModuleFileNameEx(WindowProcess, WindowModule, Buffer, Length(Buffer)) = 0 then
      Exit;
    WindowModuleName := Buffer;
    CloseHandle(WindowProcess); // not needed anymore
""", """    // Get its module filename
    try
      if GetModuleFileNameEx(WindowProcess, WindowModule, Buffer, Length(Buffer)) = 0 then
        Exit;
      WindowModuleName := Buffer;
    finally
      CloseHandle(WindowProcess); // closed on the Exit too: it leaked there
    end;
""")

# 3. Waiting for the previous instance's window: give up after 10 s, not never
once("""    // Temporary fix: try to find the MainForm handle every 100ms

    while True do begin
      if not EnumWindows(@GetPreviousInstanceCallback, LPARAM(PString(@ThisModuleFileName))) then begin
        Result := PreviousInstance;
        Exit;
      end;
      Sleep(100);
    end;""", """    // Temporary fix: try to find the MainForm handle every 100ms
    // For 10 seconds: the mutex's owner may be another Dev-C++ executable (another file name),
    // whose window never matches; "while True" then waited forever. Then: run as a new instance.
    for var Attempt := 1 to 100 do begin
      if not EnumWindows(@GetPreviousInstanceCallback, LPARAM(PString(@ThisModuleFileName))) then begin
        Result := PreviousInstance;
        Exit;
      end;
      Sleep(100);
    end;""")

open(p, "wb").write(t.encode("latin-1"))
print("ok", p)
