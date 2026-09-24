"""Collects every player-facing message from the GDScript sources into locale/messages.pot and
writes game/i18n/messages.gd (the rules-text patterns BMLoc.tf matches).

Run:  python tools/i18n/extract.py

What counts as a message (English source text is the msgid):
  BMLoc.t("text")  BMLoc.t("text", &"context")   UI text, translated where it is shown
  BMLoc.tn("one", "many", n)                       plural UI text
  BMLoc.m("text")  BMLoc.mn("one", "many", n)      rules text: stays English in the rules and in
                                                   saves; the UI shows it through BMLoc.tf()
  const X := [...]  # i18n                          every string value of the constant
  const X := {...}  # i18n: name, text              the values of those keys only
  ... # i18n ctx=tier                               with a msgctxt

Then run tools/i18n/update_po.py to merge new messages into locale/*.po, and
tools/i18n/check.py to verify the translations and font coverage.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "game")
POT = os.path.join(ROOT, "locale", "messages.pot")
PATTERNS_GD = os.path.join(ROOT, "game", "i18n", "messages.gd")

ESCAPES = {"n": "\n", "t": "\t", '"': '"', "'": "'", "\\": "\\", "r": "\r"}


def read_string(src, i):
    """Parses a "..." literal starting at src[i] == '"'. Returns (value, index after it)."""
    assert src[i] == '"'
    i += 1
    out = []
    while i < len(src):
        c = src[i]
        if c == "\\":
            nxt = src[i + 1]
            if nxt == "u":
                out.append(chr(int(src[i + 2:i + 6], 16)))
                i += 6
                continue
            out.append(ESCAPES.get(nxt, nxt))
            i += 2
            continue
        if c == '"':
            return "".join(out), i + 1
        out.append(c)
        i += 1
    raise ValueError("unterminated string")


def skip_ws(src, i):
    while i < len(src) and src[i] in " \t\r\n\\":
        i += 1
    return i


class Catalog:
    def __init__(self):
        self.entries = {}  # (ctx, msgid) -> {"plural": str, "refs": [..], "rules": bool}

    def add(self, msgid, ref, ctx="", plural="", rules=False):
        if msgid.strip() == "":
            return
        key = (ctx, msgid)
        e = self.entries.setdefault(key, {"plural": "", "refs": [], "rules": False})
        if plural:
            if e["plural"] and e["plural"] != plural:
                print("WARNING: %s has two plural forms: %r / %r" % (msgid, e["plural"], plural))
            e["plural"] = plural
        if ref not in e["refs"]:
            e["refs"].append(ref)
        e["rules"] = e["rules"] or rules


CALL = re.compile(r"BMLoc\.(tn|mn|t|m)\(")
MARKER = re.compile(r"#\s*i18n\b(.*)$")


def line_of(src, i):
    return src.count("\n", 0, i) + 1


def scan_calls(src, rel, cat):
    for mt in CALL.finditer(src):
        fn = mt.group(1)
        i = skip_ws(src, mt.end())
        if i >= len(src) or src[i] != '"':
            continue  # a variable: its values are collected elsewhere
        ref = "%s:%d" % (rel, line_of(src, mt.start()))
        first, i = read_string(src, i)
        i = skip_ws(src, i)
        if fn in ("tn", "mn"):
            if src[i] != ",":
                print("WARNING: %s %s without a plural literal" % (ref, fn))
                continue
            i = skip_ws(src, i + 1)
            if src[i] != '"':
                print("WARNING: %s %s plural is not a literal" % (ref, fn))
                continue
            plural, i = read_string(src, i)
            cat.add(first, ref, plural=plural, rules=fn == "mn")
            continue
        ctx = ""
        if src[i] == ",":
            j = skip_ws(src, i + 1)
            if src.startswith('&"', j):
                ctx, _ = read_string(src, j + 1)
        cat.add(first, ref, ctx=ctx, rules=fn == "m")


def bracket_block(src, i):
    """The text of the bracketed expression starting at src[i] in '[{(' (strings and comments
    respected). Returns (start, end) indices."""
    depth = 0
    j = i
    while j < len(src):
        c = src[j]
        if c == '"':
            _, j = read_string(src, j)
            continue
        if c == "#":
            while j < len(src) and src[j] != "\n":
                j += 1
            continue
        if c in "[{(":
            depth += 1
        elif c in "]})":
            depth -= 1
            if depth == 0:
                return i, j + 1
        j += 1
    raise ValueError("unbalanced constant")


def scan_constants(src, rel, cat):
    for mt in re.finditer(r"^const\s+(\w+)\s*(?::\s*\w+\s*)?:?=\s*", src, re.M):
        line_end = src.find("\n", mt.end())
        first_line = src[mt.start():line_end]
        mk = MARKER.search(first_line)
        if not mk:
            continue
        spec = mk.group(1).strip()
        ctx = ""
        keys = None
        cm = re.search(r"ctx=(\w+)", spec)
        if cm:
            ctx = cm.group(1)
            spec = spec.replace(cm.group(0), "").strip()
        if spec.startswith(":"):
            keys = {k.strip() for k in spec[1:].split(",") if k.strip()}
        start = mt.end()
        if src[start] not in "[{":
            continue
        a, b = bracket_block(src, start)
        j = a
        while j < b:
            c = src[j]
            if c == "#":
                while j < b and src[j] != "\n":
                    j += 1
                continue
            if c != '"':
                j += 1
                continue
            lit_start = j
            value, j = read_string(src, j)
            k = skip_ws(src, j)
            if k < b and src[k] == ":":
                continue  # a dictionary key
            if keys is not None:
                # The key right before this value: "key": "value"
                before = src[a:lit_start].rstrip()
                km = re.search(r'"(\w+)"\s*:\s*$', before)
                if not km or km.group(1) not in keys:
                    continue
            if value == "" or re.fullmatch(r"[a-z0-9_]+", value) and keys is None:
                continue  # ids in an "all strings" constant
            cat.add(value, "%s:%d" % (rel, line_of(src, lit_start)), ctx=ctx)


def po_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def po_string(keyword, s):
    if "\n" in s[:-1]:
        parts = s.split("\n")
        lines = [p + "\n" for p in parts[:-1]] + ([parts[-1]] if parts[-1] else [])
        return '%s ""\n' % keyword + "".join('"%s"\n' % po_escape(l) for l in lines)
    return '%s "%s"\n' % (keyword, po_escape(s))


def write_pot(cat):
    os.makedirs(os.path.dirname(POT), exist_ok=True)
    out = ['msgid ""\n', 'msgstr ""\n', '"Project-Id-Version: BLOCKMANIA\\n"\n',
           '"Content-Type: text/plain; charset=UTF-8\\n"\n', '"Content-Transfer-Encoding: 8bit\\n"\n', "\n"]
    for (ctx, msgid) in sorted(cat.entries, key=lambda k: (cat.entries[k]["refs"][0].split(":")[0], int(cat.entries[k]["refs"][0].split(":")[1]), k)):
        e = cat.entries[(ctx, msgid)]
        if e["rules"]:
            out.append("#. rules text (shown through BMLoc.tf)\n")
        out.append("#: " + " ".join(e["refs"][:6]) + "\n")
        if "%" in msgid or "{" in msgid:
            out.append("#, c-format\n" if "%" in msgid else "")
        if ctx:
            out.append('msgctxt "%s"\n' % po_escape(ctx))
        out.append(po_string("msgid", msgid))
        if e["plural"]:
            out.append(po_string("msgid_plural", e["plural"]))
            out.append('msgstr[0] ""\nmsgstr[1] ""\n\n')
        else:
            out.append('msgstr ""\n\n')
    with open(POT, "w", encoding="utf-8", newline="\n") as f:
        f.write("".join(out))


def gd_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t") + '"'


def write_patterns(cat):
    rows = []
    for (ctx, msgid), e in sorted(cat.entries.items(), key=lambda kv: kv[0][1]):
        if not e["rules"]:
            continue
        if not re.search(r"%(\.\d+)?[dsf]", msgid):
            continue
        rows.append("\t[%s, %s, %s]," % (gd_string(msgid), gd_string(e["plural"]), gd_string(ctx)))
    text = ("class_name BMMessages\nextends RefCounted\n## GENERATED by tools/i18n/extract.py: do not edit. The rules messages with placeholders\n"
            "## ([msgid, plural, context]) that BMLoc.tf recognizes in English rules text.\n\nconst PATTERNS := [\n"
            + "\n".join(rows) + "\n]\n")
    with open(PATTERNS_GD, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    return len(rows)


def collect():
    cat = Catalog()
    for dirpath, _, files in os.walk(SRC):
        for fn in sorted(files):
            if not fn.endswith(".gd") or fn == "messages.gd":
                continue
            path = os.path.join(dirpath, fn)
            rel = os.path.relpath(path, ROOT).replace("\\", "/")
            src = open(path, encoding="utf-8").read()
            scan_calls(src, rel, cat)
            scan_constants(src, rel, cat)
    return cat


def main():
    cat = collect()
    write_pot(cat)
    n = write_patterns(cat)
    plurals = sum(1 for e in cat.entries.values() if e["plural"])
    print("messages: %d (%d plural, %d rules patterns) -> %s" % (len(cat.entries), plurals, n, os.path.relpath(POT, ROOT)))


if __name__ == "__main__":
    sys.exit(main())
