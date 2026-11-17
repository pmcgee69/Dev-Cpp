"""Temporary (never committed): devcpp.exe -runtests <file> runs TTestClass.TestEditorList after
the first show, writes PASS or the exception to <file>, and closes.  usage: runtests_patch.py <main.pas> [--undo]"""
import sys
p = sys.argv[1]
b = open(p, "rb").read()
t = b.decode("latin-1")
nl = "\r\n" if "\r\n" in t else "\n"
mark = "{RUNTESTS-TEMP}"
anchor = "      RestoreToolbarPositions;" + nl + "    end);"
add = (nl + "  " + mark + " if GetEnvironmentVariable('DEVCPP_RUNTESTS') <> '' then TThread.ForceQueue(nil, procedure" + nl +
       "    var Res: string; F: TextFile; begin" + nl +
       "      try with TTestClass.Create do try if TestEditorList then Res := 'PASS' else Res := 'FALSE'; finally Free; end;" + nl +
       "      except on E: Exception do Res := 'FAIL ' + E.ClassName + ': ' + E.Message; end;" + nl +
       "      AssignFile(F, GetEnvironmentVariable('DEVCPP_RUNTESTS')); Rewrite(F); Writeln(F, Res); CloseFile(F); Close; end);")
if "--undo" in sys.argv:
    i = t.find(nl + "  " + mark)
    assert i >= 0
    j = t.find("CloseFile(F); Close; end);", i) + len("CloseFile(F); Close; end);")
    t = t[:i] + t[j:]
else:
    assert t.count(anchor) == 1 and mark not in t
    t = t.replace(anchor, anchor + add)
    # Tests must be in main's implementation uses
    if "Tests" not in t[t.find("implementation"):t.find("implementation") + 3000]:
        u = t.find("uses", t.find("implementation"))
        t = t[:u + 4] + nl + "  Tests," + t[u + 4:]
open(p, "wb").write(t.encode("latin-1"))
print("undone" if "--undo" in sys.argv else "patched")
