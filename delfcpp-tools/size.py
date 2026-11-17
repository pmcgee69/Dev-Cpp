"""Dev-C++'s size: lines and files by kind, Dev-C++'s own code apart from bundled third-party
libraries and the separate tools. Reads the committed tree of a git ref, so line endings and
working-tree changes don't matter.  usage: size.py <repo> <ref>"""
import collections, subprocess, sys

repo, ref = sys.argv[1], sys.argv[2]
files = subprocess.run(["git", "-C", repo, "ls-tree", "-r", "--name-only", ref, "Source"],
                       capture_output=True, text=True).stdout.split()
third = ("Source/VCL/SynEdit/", "Source/VCL/SVGIconImageList/", "Source/VCL/vcl-styles-utils/",
         "Source/VCL/DDetours/", "Source/VCL/Abbrevia/")
def group(p):
    if p.startswith(third):
        return "third-party (SynEdit, SVGIconImageList, vcl-styles-utils, DDetours, Abbrevia)"
    if p.startswith("Source/Tools/"):
        return "separate tools (Packman, PackMaker, ...)"
    return "Dev-C++'s own"
kinds = (".pas", ".delf", ".dfm", ".dpr", ".inc")
stats = collections.defaultdict(lambda: collections.Counter())
for p in files:
    ext = p[p.rfind("."):].lower() if "." in p else ""
    if ext not in kinds:
        continue
    data = subprocess.run(["git", "-C", repo, "show", f"{ref}:{p}"], capture_output=True).stdout
    g = group(p)
    stats[g][ext + " files"] += 1
    stats[g][ext + " lines"] += data.count(b"\n")
for g in sorted(stats):
    c = stats[g]
    print(g)
    for ext in kinds:
        if c[ext + " files"]:
            print(f"   {ext:5} {c[ext + ' files']:5} files {c[ext + ' lines']:8} lines")
