"""Generates BLOCKMANIA's custom mouse cursors (original pixel art, authored as code).

Run:  python tools/art/gen_cursor.py
Out:  assets/ui/cursor_*.png at 1x art pixels (BMCursor scales them by a whole number for the
      window and hands them to the OS as hardware cursors, so they never lag behind the mouse):
      arrow, arrow_press      chunky cream arrow with an ink outline and a sun glint
      hand, hand_b            POPS's white glove pointing up (two frames: the fingers wiggle)
      hand_press              the glove mid-click: the finger pushed down by two pixels
      grab                    the glove closed, for dragging
Hotspots are listed in HOTSPOTS (also used by BMCursor): the arrow tip and the fingertip.
"""
import os
from PIL import Image

import gen_ui as ui

OUT = os.path.join(ui.ROOT, "assets", "ui")
PAL = dict(ui.ICON_PALETTE)
PAL.update({"s": ui.INK_SOFT})

ARROW = [
    "k...........",
    "kk..........",
    "kwk.........",
    "kwck........",
    "kwcck.......",
    "kwccck......",
    "kwcccck.....",
    "kwccccck....",
    "kwcccccck...",
    "kwccccccck..",
    "kwcccccCkkk.",
    "kwcckcCk....",
    "kwckkcCk....",
    "kwk..kcCk...",
    "kk...kcCk...",
    "k.....kcCk..",
    "......kcCk..",
    ".......kk...",
]

HAND = [
    ".....kk.........",
    "....kwwk........",
    "....kwwk........",
    "....kwwk........",
    "....kwwkkk......",
    "....kwwkwwkkk...",
    ".kk.kwwkwwkwwk..",
    "kwwkkwwkwwkwwkk.",
    "kwwwkwwwwwwwwwCk",
    ".kwwwwwwwwwwwwCk",
    "..kwwwwwwwwwwwCk",
    "..kwwwwwwwwwwCCk",
    "...kwwwwwwwwCCk.",
    "....kwwwwwwCCk..",
    "....kyYYYYYYok..",
    "....kkkkkkkkkk..",
]

# The glove folded into a fist, for dragging.
GRAB = [
    "................",
    "................",
    "................",
    "................",
    "....kk.kk.kk....",
    "...kwwkwwkwwkk..",
    "..kwwwkwwkwwkwk.",
    ".kwwwwwwwwwwwwCk",
    ".kwkwwwwwwwwwwCk",
    ".kwwkwwwwwwwwwCk",
    "..kwwwwwwwwwwwCk",
    "..kwwwwwwwwwwCCk",
    "...kwwwwwwwwCCk.",
    "....kwwwwwwCCk..",
    "....kyYYYYYYok..",
    "....kkkkkkkkkk..",
]

HOTSPOTS = {"arrow": (0, 0), "arrow_press": (0, 0), "hand": (5, 0), "hand_b": (5, 1),
            "hand_press": (5, 2), "grab": (8, 5)}


def draw(rows, recolor=None):
    w = max(len(r) for r in rows)
    im = Image.new("RGBA", (w + 1, len(rows) + 1), (0, 0, 0, 0))
    # A soft ink shadow one pixel down-right, under the art.
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                im.putpixel((x + 1, y + 1), ui.INK_SOFT)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            c = PAL[ch]
            if recolor and ch in recolor:
                c = PAL[recolor[ch]]
            im.putpixel((x, y), c)
    return im


def shifted(rows, dy, cut_from, cut):
    """Rows with `cut` rows removed at `cut_from` and `dy` blank rows on top (a press/bob)."""
    body = rows[:cut_from] + rows[cut_from + cut:]
    return ["." * len(rows[0])] * dy + body


def main():
    out = {
        "arrow": draw(ARROW),
        # Pressed: the arrow lights up sun-yellow for the click.
        "arrow_press": draw(ARROW, {"c": "y", "C": "o", "w": "w"}),
        "hand": draw(HAND),
        "hand_b": draw(shifted(HAND, 1, 2, 1)),
        "hand_press": draw(shifted(HAND, 2, 2, 2)),
        "grab": draw(GRAB),
    }
    for name, im in out.items():
        im.save(os.path.join(OUT, "cursor_%s.png" % name))
    print("wrote %d cursors to %s" % (len(out), OUT))


if __name__ == "__main__":
    main()
