"""The DelfCpp discussion as Markdown: the user's words and Claude's replies (text only, no tool
calls), from the first message about 64-bit Dev-C++ on.  usage: transcript.py <session.jsonl> <out.md>"""
import json, sys

src, out = sys.argv[1], sys.argv[2]
START = ("64bit app", "64 bit", "think about 64")
rows, started = [], False
for line in open(src, encoding="utf-8"):
    try:
        e = json.loads(line)
    except ValueError:
        continue
    if e.get("type") not in ("user", "assistant") or e.get("isMeta") or e.get("isCompactSummary"):
        continue
    msg = e.get("message") or {}
    content = msg.get("content")
    texts = []
    if isinstance(content, str):
        texts = [content]
    elif isinstance(content, list):
        texts = [c.get("text", "") for c in content if isinstance(c, dict) and c.get("type") == "text"]
    text = "\n".join(t for t in texts if t).strip()
    if not text or text.startswith("<system-reminder>") or text.startswith("<command-") \
            or "This session is being continued" in text or text.startswith("[Request interrupted"):
        if text.startswith("[Request interrupted"):
            rows.append(("note", "(the user interrupted)", e.get("timestamp", "")))
        continue
    if not started:
        if e["type"] == "user" and any(s in text for s in START):
            started = True
        else:
            continue
    rows.append((e["type"], text, e.get("timestamp", "")))

with open(out, "w", encoding="utf-8", newline="\n") as f:
    f.write("# DelfCpp: the discussion, from the start\n\n")
    f.write("The user's messages and Claude's replies in the Claude Code session that started DelfCpp\n"
            "(Dev-C++ to Win64, then into Delf), from the first message about 64-bit on. Text only:\n"
            "tool calls and their output are left out. Earlier in the same session: Dev-C++'s HiDPI\n"
            "toolbar work. Generated from the session log on 18 Nov 2026.\n\n")
    for who, text, ts in rows:
        if who == "note":
            f.write(f"*{text}*\n\n")
            continue
        head = "**User**" if who == "user" else "**Claude**"
        f.write(f"---\n\n{head} <sub>{ts[:16].replace('T', ' ')} UTC</sub>\n\n{text}\n\n")
print(len(rows), "messages")
