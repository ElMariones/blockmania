"""Minimal gettext PO reader/writer for BLOCKMANIA's locale files (UTF-8, msgctxt, plurals)."""
import re

LANGS = {
    "es": ("Spanish", "nplurals=2; plural=(n != 1);"),
    "fr": ("French", "nplurals=2; plural=(n > 1);"),
    "it": ("Italian", "nplurals=2; plural=(n != 1);"),
    "de": ("German", "nplurals=2; plural=(n != 1);"),
    "nl": ("Dutch", "nplurals=2; plural=(n != 1);"),
    "pl": ("Polish", "nplurals=3; plural=(n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2);"),
    "pt_BR": ("Brazilian Portuguese", "nplurals=2; plural=(n > 1);"),
    "ja": ("Japanese", "nplurals=1; plural=0;"),
    "zh_CN": ("Simplified Chinese", "nplurals=1; plural=0;"),
    "zh_TW": ("Traditional Chinese", "nplurals=1; plural=0;"),
}
CJK = ("ja", "zh_CN", "zh_TW")
NL = "\n"


def nplurals(lang):
    return int(re.search(r"nplurals=(\d+)", LANGS[lang][1]).group(1))


def _unquote(s):
    s = s.strip()
    assert s.startswith('"') and s.endswith('"'), s
    body = s[1:-1]
    out = []
    i = 0
    while i < len(body):
        c = body[i]
        if c == "\\":
            n = body[i + 1]
            out.append({"n": NL, "t": "\t", '"': '"', "\\": "\\"}.get(n, n))
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace(NL, "\\n").replace("\t", "\\t")


def read(path):
    """Returns (header_text, [entry]) where entry = {ctx, id, plural, str (str, or a list for
    plurals), comments}. Entries are separated by blank lines (as every file here is written)."""
    with open(path, encoding="utf-8") as f:
        blocks = [b for b in f.read().split(NL + NL) if b.strip()]
    entries = []
    for block in blocks:
        e = {"ctx": "", "id": "", "plural": "", "str": "", "comments": []}
        field = None
        for line in block.split(NL):
            if line.startswith("#"):
                e["comments"].append(line)
                continue
            if not line.strip():
                continue
            m = re.match(r'^(msgctxt|msgid_plural|msgid|msgstr)(?:\[(\d+)\])?\s+(".*")$', line)
            if m:
                kw, idx, val = m.group(1), m.group(2), _unquote(m.group(3))
                if kw == "msgstr" and idx is not None:
                    if not isinstance(e["str"], list):
                        e["str"] = []
                    i = int(idx)
                    while len(e["str"]) <= i:
                        e["str"].append("")
                    e["str"][i] = val
                    field = ("str", i)
                else:
                    key = {"msgctxt": "ctx", "msgid": "id", "msgid_plural": "plural", "msgstr": "str"}[kw]
                    e[key] = val
                    field = (key, None)
                continue
            if line.startswith('"') and field is not None:
                val = _unquote(line)
                key, i = field
                if i is None:
                    e[key] += val
                else:
                    e["str"][i] += val
        entries.append(e)
    header = ""
    if entries and entries[0]["id"] == "" and entries[0]["ctx"] == "":
        header = entries[0]["str"] if isinstance(entries[0]["str"], str) else ""
        entries = entries[1:]
    return header, entries


def _field(keyword, s):
    if NL in s[:-1]:
        parts = s.split(NL)
        chunks = [p + NL for p in parts[:-1]] + ([parts[-1]] if parts[-1] else [])
        return '%s ""\n' % keyword + "".join('"%s"\n' % escape(c) for c in chunks)
    return '%s "%s"\n' % (keyword, escape(s))


def write(path, header, entries):
    out = ['msgid ""\n', 'msgstr ""\n']
    for hl in header.split(NL):
        if hl:
            out.append('"%s\\n"\n' % escape(hl))
    out.append(NL)
    for e in entries:
        for c in e.get("comments", []):
            out.append(c + NL)
        if e["ctx"]:
            out.append(_field("msgctxt", e["ctx"]))
        out.append(_field("msgid", e["id"]))
        if e["plural"]:
            out.append(_field("msgid_plural", e["plural"]))
            forms = e["str"] if isinstance(e["str"], list) else [e["str"]]
            for i, s in enumerate(forms):
                out.append(_field("msgstr[%d]" % i, s))
        else:
            out.append(_field("msgstr", e["str"] if isinstance(e["str"], str) else ""))
        out.append(NL)
    with open(path, "w", encoding="utf-8", newline=NL) as f:
        f.write("".join(out))
