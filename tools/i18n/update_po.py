"""Merges locale/messages.pot into every locale/<lang>.po: new messages are added untranslated,
translations of unchanged messages are kept, and messages that left the game are dropped.

Run:  python tools/i18n/extract.py && python tools/i18n/update_po.py
Then translate the empty msgstr entries and run python tools/i18n/check.py.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import po  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LOCALE = os.path.join(ROOT, "locale")


def header(lang):
    name, forms = po.LANGS[lang]
    return "\n".join([
        "Project-Id-Version: BLOCKMANIA",
        "Language: %s" % lang,
        "Language-Team: %s" % name,
        "MIME-Version: 1.0",
        "Content-Type: text/plain; charset=UTF-8",
        "Content-Transfer-Encoding: 8bit",
        "Plural-Forms: %s" % forms,
    ])


def merge(lang, template):
    path = os.path.join(LOCALE, lang + ".po")
    old = {}
    if os.path.exists(path):
        _, entries = po.read(path)
        old = {(e["ctx"], e["id"]): e for e in entries}
    n = po.nplurals(lang)
    out = []
    missing = 0
    for t in template:
        e = {"ctx": t["ctx"], "id": t["id"], "plural": t["plural"], "comments": t["comments"]}
        prev = old.get((t["ctx"], t["id"]))
        if t["plural"]:
            forms = prev["str"] if prev is not None and isinstance(prev["str"], list) else []
            forms = (list(forms) + [""] * n)[:n]
            e["str"] = forms
            missing += 0 if all(forms) else 1
        else:
            s = prev["str"] if prev is not None and isinstance(prev["str"], str) else ""
            e["str"] = s
            missing += 0 if s else 1
        out.append(e)
    po.write(path, header(lang), out)
    return len(out), missing


def main():
    _, template = po.read(os.path.join(LOCALE, "messages.pot"))
    for lang in po.LANGS:
        total, missing = merge(lang, template)
        print("%-6s %d messages, %d untranslated" % (lang, total, missing))


if __name__ == "__main__":
    main()
