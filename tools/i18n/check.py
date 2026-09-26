"""Verifies every locale/<lang>.po against the template and the fonts.

Run:  python tools/i18n/check.py        (exit code 0 = every language is complete and consistent)

Checks, per message and language:
  - translated (every plural form filled in);
  - the same printf placeholders in the same order (%d, %s, %.1f, %02d, %%) and the same
    {named} placeholders, since GDScript's % operator cannot reorder arguments;
  - leading/trailing spaces and newlines kept (they glue strings together in code);
  - an ALL-CAPS English message stays in capitals (Latin-script languages);
  - every character has a glyph: Blockhead for Latin languages, Blockhead + the language's CJK
    subset (tools/art/gen_cjk_fonts.py) for Japanese and Chinese.
"""
import os
import re
import sys

from fontTools.ttLib import TTFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import po  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PRINTF = re.compile(r"%[-+ #0]*\d*(?:\.\d+)?[dsf%]")
NAMED = re.compile(r"\{[a-z_]+\}")


def cmap(path):
    return set(TTFont(path).getBestCmap().keys())


def edge(s):
    lead = re.match(r"^[ \n]*", s).group(0)
    trail = re.search(r"[ \n]*$", s).group(0)
    return lead, trail


def main():
    _, template = po.read(os.path.join(ROOT, "locale", "messages.pot"))
    fonts = os.path.join(ROOT, "assets", "fonts")
    latin = cmap(os.path.join(fonts, "blockhead.ttf")) & cmap(os.path.join(fonts, "blockhead_bold.ttf"))
    latin |= {0x20, 0x0A}
    problems = 0
    for lang in po.LANGS:
        glyphs = set(latin)
        if lang in po.CJK:
            glyphs |= cmap(os.path.join(fonts, "cjk_%s.ttf" % lang.lower()))
        _, entries = po.read(os.path.join(ROOT, "locale", lang + ".po"))
        by_key = {(e["ctx"], e["id"]): e for e in entries}
        issues = []
        for t in template:
            e = by_key.get((t["ctx"], t["id"]))
            label = t["id"][:60].replace("\n", "\\n")
            if e is None:
                issues.append("missing entry: %s" % label)
                continue
            forms = e["str"] if isinstance(e["str"], list) else [e["str"]]
            if t["plural"] and len(forms) != po.nplurals(lang):
                issues.append("%d plural forms, need %d: %s" % (len(forms), po.nplurals(lang), label))
            for i, s in enumerate(forms):
                src = t["plural"] if (t["plural"] and i > 0) else t["id"]
                if s == "":
                    issues.append("untranslated: %s" % label)
                    continue
                if PRINTF.findall(s) != PRINTF.findall(src):
                    issues.append("placeholders %s != %s: %s" % (PRINTF.findall(s), PRINTF.findall(src), label))
                if sorted(NAMED.findall(s)) != sorted(NAMED.findall(src)):
                    issues.append("named placeholders differ: %s" % label)
                # CJK text drops the spaces around words (fullwidth punctuation takes their place).
                if edge(s) != edge(src) and not (lang in po.CJK and edge(s)[0].replace(" ", "") == edge(src)[0].replace(" ", "")
                                                 and edge(s)[1].replace(" ", "") == edge(src)[1].replace(" ", "")):
                    issues.append("leading/trailing space or newline differs: %r -> %r" % (src, s))
                letters = re.sub(PRINTF, "", src)
                if lang not in po.CJK and re.search(r"[A-Za-z]{2}", letters) and letters == letters.upper():
                    body = re.sub(PRINTF, "", s)
                    if body != body.upper():
                        issues.append("should be ALL CAPS: %r" % s)
                bad = sorted({c for c in s if ord(c) not in glyphs})
                if bad:
                    issues.append("no glyph for %s in %r" % ("".join(bad), s[:60]))
        for i in issues:
            print("%-6s %s" % (lang, i))
        problems += len(issues)
        print("%-6s %d messages, %d problems" % (lang, len(template), len(issues)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
