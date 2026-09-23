"""Generates BLOCKMANIA's original pixel typeface ("Blockhead") as a TrueType font.

Run:  python tools/art/gen_font.py
Out:  assets/fonts/blockhead.ttf

Every glyph is drawn by hand below on a pixel grid: rows 0-1 are the ascender zone for
lowercase ascenders, rows 1-7 the cap height (7 rows), rows 8-9 the descender zone. One font pixel
= 100 units, em = 1000 units, so a Godot font_size of N draws N/10 screen pixels per font pixel:
use sizes 20, 30, 40, 60, 80 for crisp integer scaling. '#' = ink, '.' = empty.
License: original work for BLOCKMANIA (no third-party glyph data).
"""
import os
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

PX = 100
ASC_ROWS = 8   # rows above baseline (0..7), baseline sits below row 7
DESC_ROWS = 2  # rows 8..9
TRACK = 1      # empty columns after each glyph

# Glyph rows are listed top (row 0) to bottom (row 9). Rows may be shorter than 10;
# missing rows are empty. Capitals use rows 1-7.
G = {}


def g(ch, *rows):
    G[ch] = list(rows)


E = ""  # empty row shorthand
# --- Uppercase (rows 1..7) ---
g("A", E, ".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#")
g("B", E, "####.", "#...#", "#...#", "####.", "#...#", "#...#", "####.")
g("C", E, ".###.", "#...#", "#....", "#....", "#....", "#...#", ".###.")
g("D", E, "####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####.")
g("E", E, "#####", "#....", "#....", "####.", "#....", "#....", "#####")
g("F", E, "#####", "#....", "#....", "####.", "#....", "#....", "#....")
g("G", E, ".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####")
g("H", E, "#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#")
g("I", E, "###", ".#.", ".#.", ".#.", ".#.", ".#.", "###")
g("J", E, "..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##..")
g("K", E, "#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#")
g("L", E, "#....", "#....", "#....", "#....", "#....", "#....", "#####")
g("M", E, "#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#")
g("N", E, "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#")
g("O", E, ".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###.")
g("P", E, "####.", "#...#", "#...#", "####.", "#....", "#....", "#....")
g("Q", E, ".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#")
g("R", E, "####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#")
g("S", E, ".####", "#....", "#....", ".###.", "....#", "....#", "####.")
g("T", E, "#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#..")
g("U", E, "#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###.")
g("V", E, "#...#", "#...#", "#...#", "#...#", ".#.#.", ".#.#.", "..#..")
g("W", E, "#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#")
g("X", E, "#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#")
g("Y", E, "#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#..")
g("Z", E, "#####", "....#", "...#.", "..#..", ".#...", "#....", "#####")
# --- Lowercase (x-height rows 3..7, ascenders from row 1, descenders rows 8..9) ---
g("a", E, E, E, ".###.", "....#", ".####", "#...#", ".####")
g("b", E, "#....", "#....", "####.", "#...#", "#...#", "#...#", "####.")
g("c", E, E, E, ".###.", "#....", "#....", "#....", ".###.")
g("d", E, "....#", "....#", ".####", "#...#", "#...#", "#...#", ".####")
g("e", E, E, E, ".###.", "#...#", "#####", "#....", ".###.")
g("f", E, "..##", ".#..", ".#..", "###.", ".#..", ".#..", ".#..")
g("g", E, E, E, ".####", "#...#", "#...#", "#...#", ".####", "....#", ".###.")
g("h", E, "#....", "#....", "####.", "#...#", "#...#", "#...#", "#...#")
g("i", E, "#", E, "#", "#", "#", "#", "#")
g("j", E, "..#", E, "..#", "..#", "..#", "..#", "..#", "..#", "##.")
g("k", E, "#...", "#...", "#..#", "#.#.", "##..", "#.#.", "#..#")
g("l", E, "#.", "#.", "#.", "#.", "#.", "#.", ".#")
g("m", E, E, E, "##.#.", "#.#.#", "#.#.#", "#.#.#", "#.#.#")
g("n", E, E, E, "####.", "#...#", "#...#", "#...#", "#...#")
g("o", E, E, E, ".###.", "#...#", "#...#", "#...#", ".###.")
g("p", E, E, E, "####.", "#...#", "#...#", "#...#", "####.", "#....", "#....")
g("q", E, E, E, ".####", "#...#", "#...#", "#...#", ".####", "....#", "....#")
g("r", E, E, E, "#.##", "##..", "#...", "#...", "#...")
g("s", E, E, E, ".###", "#...", ".##.", "...#", "###.")
g("t", E, ".#..", ".#..", "###.", ".#..", ".#..", ".#..", "..##")
g("u", E, E, E, "#...#", "#...#", "#...#", "#...#", ".####")
g("v", E, E, E, "#...#", "#...#", ".#.#.", ".#.#.", "..#..")
g("w", E, E, E, "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#.")
g("x", E, E, E, "#...#", ".#.#.", "..#..", ".#.#.", "#...#")
g("y", E, E, E, "#...#", "#...#", "#...#", "#...#", ".####", "....#", ".###.")
g("z", E, E, E, "#####", "...#.", "..#..", ".#...", "#####")
# --- Digits (rows 1..7) ---
g("0", E, ".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###.")
g("1", E, "..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###.")
g("2", E, ".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####")
g("3", E, "####.", "....#", "....#", ".###.", "....#", "....#", "####.")
g("4", E, "...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#.")
g("5", E, "#####", "#....", "####.", "....#", "....#", "#...#", ".###.")
g("6", E, ".###.", "#....", "#....", "####.", "#...#", "#...#", ".###.")
g("7", E, "#####", "....#", "...#.", "..#..", "..#..", "..#..", "..#..")
g("8", E, ".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###.")
g("9", E, ".###.", "#...#", "#...#", ".####", "....#", "....#", ".###.")
# --- Punctuation and symbols ---
g(".", E, E, E, E, E, E, E, "#")
g(",", E, E, E, E, E, E, E, "#", "#")
g(":", E, E, E, "#", E, E, E, "#")
g(";", E, E, E, "#", E, E, E, "#", "#")
g("!", E, "#", "#", "#", "#", "#", E, "#")
g("?", E, ".###.", "#...#", "....#", "...#.", "..#..", E, "..#..")
g("'", E, "#", "#")
g('"', E, "#.#", "#.#")
g("-", E, E, E, E, "###")
g("+", E, E, E, "..#..", "..#..", "#####", "..#..", "..#..")
g("=", E, E, E, "####", E, "####")
g("/", E, "....#", "...#.", "...#.", "..#..", ".#...", ".#...", "#....")
g("\\", E, "#....", ".#...", ".#...", "..#..", "...#.", "...#.", "....#")
g("(", E, ".#", "#.", "#.", "#.", "#.", "#.", ".#")
g(")", E, "#.", ".#", ".#", ".#", ".#", ".#", "#.")
g("[", E, "##", "#.", "#.", "#.", "#.", "#.", "##")
g("]", E, "##", ".#", ".#", ".#", ".#", ".#", "##")
g("%", E, "##..#", "##.#.", "...#.", "..#..", ".#...", ".#.##", "#..##")
g("&", E, ".##..", "#..#.", "#.#..", ".#...", "#.#.#", "#..#.", ".##.#")
g("#", E, ".#.#.", "#####", ".#.#.", ".#.#.", "#####", ".#.#.")
g("*", E, E, "#.#", ".#.", "#.#")
g("<", E, E, "...#", "..#.", ".#..", "..#.", "...#")
g(">", E, E, "#...", ".#..", "..#.", ".#..", "#...")
g("_", E, E, E, E, E, E, E, "#####")
g("|", E, "#", "#", "#", "#", "#", "#", "#", "#")
g("$", E, "..#..", ".####", "#.#..", ".###.", "..#.#", "####.", "..#..")
g("@", E, ".###.", "#...#", "#.###", "#.#.#", "#.###", "#....", ".###.")
g("^", E, ".#.", "#.#")
g("~", E, E, E, ".#.#", "#.#.")
g("`", E, "#.", ".#")
g("×", E, E, E, "#...#", ".#.#.", "..#..", ".#.#.", "#...#")
g("·", E, E, E, E, "#")
g("•", E, E, E, "##", "##")
g("–", E, E, E, E, "####")
g("—", E, E, E, E, "#####")
g("…", E, E, E, E, E, E, E, "#.#.#")
g("→", E, E, "...#.", "....#", "#####", "....#", "...#.")
g("←", E, E, ".#...", "#....", "#####", "#....", ".#...")
g("↑", E, "..#..", ".###.", "#.#.#", "..#..", "..#..", "..#..", "..#..")
g("↓", E, "..#..", "..#..", "..#..", "..#..", "#.#.#", ".###.", "..#..")
g("★", E, "..#..", "..#..", "#####", ".###.", ".#.#.", "#...#")
g("♥", E, E, ".#.#.", "#####", "#####", ".###.", "..#..")
g("°", E, ".#.", "#.#", ".#.")
g("{", E, "..#", ".#.", ".#.", "#..", ".#.", ".#.", "..#")
g("}", E, "#..", ".#.", ".#.", "..#", ".#.", ".#.", "#..")
g("’", E, "#", "#")
g("‘", E, "#", "#")
g("“", E, "#.#", "#.#")
g("”", E, "#.#", "#.#")


def glyph_width(rows):
    return max((len(r) for r in rows), default=0)


def emboldened(rows):
    """Pixel-font bold: every ink pixel also inks its right neighbour (glyph grows 1 column)."""
    out = []
    w = glyph_width(rows) + 1
    for r in rows:
        line = r.ljust(w - 1, ".") + "."
        cells = ["#" if (line[i] == "#" or (i > 0 and line[i - 1] == "#")) else "." for i in range(w)]
        out.append("".join(cells) if "#" in line else "")
    return out


# --- Spanish accents: marks drawn from the base glyph. Lowercase marks sit in rows 0-1 (the
# ascender zone above the x-height); capital marks use row 0, right above the cap height.
def _with_mark(base, mark_rows, first_row):
    rows = list(G[base]) + [E] * (10 - len(G[base]))
    w = glyph_width(G[base])
    for i, m in enumerate(mark_rows):
        pad = max(0, (w - len(m) + 1) // 2)
        rows[first_row + i] = ("." * pad + m).ljust(w, ".")[:max(w, len(m))]
    return rows


for _b, _a in (("a", "á"), ("e", "é"), ("o", "ó"), ("u", "ú")):
    G[_a] = _with_mark(_b, ["..#", ".#."], 0)
G["í"] = [".#", "#.", E, "#.", "#.", "#.", "#.", "#."]
G["ñ"] = _with_mark("n", [".#.#", "#.#."], 0)
G["ü"] = _with_mark("u", ["#.#"], 1)
for _b, _a in (("A", "Á"), ("E", "É"), ("I", "Í"), ("O", "Ó"), ("U", "Ú")):
    G[_a] = _with_mark(_b, [".##"], 0)
G["Ñ"] = _with_mark("N", ["#.##"], 0)
g("¡", E, "#", E, "#", "#", "#", "#", "#")
g("¿", E, "..#..", E, "..#..", ".#...", "#....", "#...#", ".###.")



def build(path, bold=False):
    names = [".notdef", "space"]
    cmap = {32: "space"}
    for ch in G:
        n = "uni%04X" % ord(ch)
        names.append(n)
        cmap[ord(ch)] = n
    fb = FontBuilder(unitsPerEm=1000, isTTF=True)
    fb.setupGlyphOrder(names)
    fb.setupCharacterMap(cmap)
    glyphs = {}
    metrics = {}
    empty = TTGlyphPen(None).glyph()
    glyphs[".notdef"] = empty
    metrics[".notdef"] = (500, 0)
    glyphs["space"] = empty
    metrics["space"] = ((5 if bold else 4) * PX, 0)
    for ch, rows in G.items():
        if bold:
            rows = emboldened(rows)
        pen = TTGlyphPen(None)
        for r, line in enumerate(rows):
            x = 0
            while x < len(line):
                if line[x] == "#":
                    start = x
                    while x < len(line) and line[x] == "#":
                        x += 1
                    # Font y-up: baseline between row 7 and 8.
                    top = (ASC_ROWS - r) * PX
                    bottom = top - PX
                    pen.moveTo((start * PX, bottom))
                    pen.lineTo((start * PX, top))
                    pen.lineTo((x * PX, top))
                    pen.lineTo((x * PX, bottom))
                    pen.closePath()
                else:
                    x += 1
        glyphs["uni%04X" % ord(ch)] = pen.glyph()
        metrics["uni%04X" % ord(ch)] = ((glyph_width(rows) + TRACK) * PX, 0)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ASC_ROWS * PX, descent=-DESC_ROWS * PX)
    fb.setupNameTable({"familyName": "Blockhead", "styleName": "Bold" if bold else "Regular",
                       "copyright": "Original typeface for BLOCKMANIA"})
    fb.setupOS2(sTypoAscender=ASC_ROWS * PX, sTypoDescender=-DESC_ROWS * PX, sTypoLineGap=PX,
                usWinAscent=ASC_ROWS * PX, usWinDescent=DESC_ROWS * PX)
    fb.setupPost()
    fb.save(path)


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    out = os.path.join(root, "assets", "fonts")
    os.makedirs(out, exist_ok=True)
    build(os.path.join(out, "blockhead.ttf"))
    build(os.path.join(out, "blockhead_bold.ttf"), bold=True)
    print("glyphs:", len(G) + 1)
