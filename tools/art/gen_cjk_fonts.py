"""Builds the CJK fallback fonts for Blockhead: Fusion Pixel 10 px (OFL-1.1, by TakWolf) subset to
the characters the Japanese, Simplified and Traditional Chinese translations use.

Run:  python tools/art/gen_cjk_fonts.py [path/to/fusion-pixel-font-dir]
Out:  assets/fonts/cjk_ja.ttf, cjk_zh_cn.ttf, cjk_zh_tw.ttf (+ the licenses in assets/fonts/licenses/)

The source is the "10px proportional TTF" release zip, unpacked (default build/fontsrc; it is not
committed). Run this again whenever locale/ja.po, zh_CN.po or zh_TW.po change:
tools/i18n/check.py fails when a translation uses a glyph the subset lacks.

Why 10 px: Blockhead's em is 10 font pixels and the UI uses sizes 20/30/40, so CJK glyphs land on
the same 2x/3x/4x pixel grid. The vertical metrics are set to Blockhead's (ascent 8, descent 2
pixels): the ideographs occupy rows -1..8, so a line with Chinese text is as tall as one without.
Fusion Pixel reserves the font name, so the subsets are renamed "Blockmania CJK" (OFL section 3).
"""
import os
import shutil
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "i18n"))
import po  # noqa: E402

SOURCES = {"ja": "ja", "zh_CN": "zh_hans", "zh_TW": "zh_hant"}
# Always included: the language names in Settings, CJK punctuation and fullwidth forms.
EXTRA = "日本語简体中文繁體中文" + "、。「」『』・…—〜！？：；，（）《》【】“”‘’" + "".join(chr(c) for c in range(0xFF01, 0xFF5F))


def used_chars(lang):
    _, entries = po.read(os.path.join(ROOT, "locale", lang + ".po"))
    chars = set(EXTRA)
    for e in entries:
        forms = e["str"] if isinstance(e["str"], list) else [e["str"]]
        for s in forms:
            chars.update(s)
    return {c for c in chars if ord(c) > 0x7E and not c.isspace()}


def build(src_dir, lang):
    src = os.path.join(src_dir, "fusion-pixel-10px-proportional-%s.ttf" % SOURCES[lang])
    font = TTFont(src)
    cmap = font.getBestCmap()
    chars = used_chars(lang)
    missing = sorted(c for c in chars if ord(c) not in cmap)
    opts = subset.Options()
    opts.layout_features = []
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    opts.hinting = False
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=[ord(c) for c in chars if ord(c) in cmap])
    sub.subset(font)
    upm = font["head"].unitsPerEm
    px = upm // 10
    font["hhea"].ascent = 8 * px
    font["hhea"].descent = -2 * px
    font["hhea"].lineGap = px
    os2 = font["OS/2"]
    os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = 8 * px, -2 * px, px
    os2.usWinAscent, os2.usWinDescent = 8 * px, 2 * px
    family = "Blockmania CJK %s" % lang.replace("_", " ")
    names = font["name"]
    for rec in list(names.names):
        if rec.nameID in (1, 3, 4, 6, 16, 17, 18, 21, 22):
            names.removeNames(nameID=rec.nameID)
    for nid, value in ((1, family), (2, "Regular"), (3, family + " Regular"), (4, family),
                       (6, family.replace(" ", "") + "-Regular")):
        names.setName(value, nid, 3, 1, 0x409)
    names.setName("Subset of Fusion Pixel Font 10px (c) 2022 TakWolf, SIL Open Font License 1.1. "
                  "Includes Ark Pixel, Boutique Bitmap 9x9 and Galmuri glyphs (see licenses/).", 0, 3, 1, 0x409)
    out = os.path.join(ROOT, "assets", "fonts", "cjk_%s.ttf" % lang.lower())
    font.save(out)
    return len(chars), missing, os.path.getsize(out)


def main():
    src_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "fontsrc")
    if not os.path.isdir(src_dir):
        # A worktree can share the main checkout's unpacked source.
        alt = os.path.join(os.path.dirname(ROOT), "blockmania", "build", "fontsrc")
        src_dir = alt if os.path.isdir(alt) else src_dir
    ok = True
    for lang in SOURCES:
        n, missing, size = build(src_dir, lang)
        print("%-6s %4d characters, %6d bytes%s" % (lang, n, size, ("  MISSING: " + "".join(missing)) if missing else ""))
        ok = ok and not missing
    lic = os.path.join(ROOT, "assets", "fonts", "licenses")
    os.makedirs(lic, exist_ok=True)
    shutil.copy(os.path.join(src_dir, "OFL.txt"), os.path.join(lic, "fusion-pixel-OFL.txt"))
    for sub_dir in os.listdir(os.path.join(src_dir, "LICENSES")):
        for fn in os.listdir(os.path.join(src_dir, "LICENSES", sub_dir)):
            shutil.copy(os.path.join(src_dir, "LICENSES", sub_dir, fn), os.path.join(lic, "%s-%s" % (sub_dir, fn)))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
