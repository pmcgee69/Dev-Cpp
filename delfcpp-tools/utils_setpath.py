"""Utils.SetPath: the PATH read into a 2,049-character buffer said to hold 4,098 (SizeOf).
Keeps bytes and line endings.  usage: utils_setpath.py <Utils.pas>"""
import sys
p = sys.argv[1]
t = open(p, "rb").read().decode("latin-1")
nl = "\r\n" if "\r\n" in t else "\n"
def once(old, new):
    global t
    old, new = old.replace("\n", nl), new.replace("\n", nl)
    assert t.count(old) == 1, old[:60]
    t = t.replace(old, new)
once("""  OldPath: array[0..2048] of char;
""", "")
once("""    GetEnvironmentVariable(PChar('PATH'), @OldPath, SizeOf(OldPath));
    NewPath := NewPath + String(OldPath);""",
     """    // SysUtils' string version: the array this read into held 2,049 characters but was given
    // as SizeOf, 4,098, so a PATH of 2,049..4,097 overran it, and a longer one appended junk
    NewPath := NewPath + Sysutils.GetEnvironmentVariable('PATH');""")
open(p, "wb").write(t.encode("latin-1"))
print("ok", p)
