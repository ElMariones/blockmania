"""Generates the Buru Arcade studio logo (original art, authored as code).

Run:  python tools/art/gen_studio_logo.py
Out:  assets/brand/  (marketing exports, kept out of the Godot import by .gdignore)
      buru_arcade_logo.png        horizontal lockup, transparent, 4x art pixels
      buru_arcade_logo_8x.png     the same at 8x, for press kits and video
      buru_arcade_mark.png        square mark (POPS over a BURU ARCADE banner), transparent
      steam_avatar_184.png        Steam creator page avatar, 184x184
      steam_header_1500x220.png   Steam creator page header background, 1500x220

Design: POPS, the arcade's caretaker (tools/art/gen_helper.py), stands behind the marquee and
points at "BURU", spelled in the title logo's chunky two-block toy letters, one candy color each, over a
plum arcade marquee with a brass rim and chaser bulbs that reads "ARCADE" in Blockhead bold.
The last U's corner block has just popped off in a burst of chips: the same pop the game
plays when a line clears or a logo letter is clicked. The launch splash (game/ui/splash_screen.gd)
builds the same lockup live and bursts it into its blocks.
"""
import os
from PIL import Image, ImageDraw, ImageFont

import gen_ui as ui
import gen_helper

ROOT = ui.ROOT
OUT = os.path.join(ROOT, "assets", "brand")
FONT = os.path.join(ROOT, "assets", "fonts", "blockhead_bold.ttf")

# Same stroke style as BMTitleScreen.LETTERS. Keep in sync with BMSplash.LETTERS.
LETTERS = {
    "B": ["#####.", "##..##", "##..##", "#####.", "##..##", "##..##", "#####."],
    "U": ["##..##", "##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
    "R": ["#####.", "##..##", "##..##", "#####.", "####..", "##.##.", "##..##"],
}
WORD = "BURU"
COLORS = ["red", "yellow", "green", "blue"]
POPPED = (3, 5, 0)  # (letter, x, y): the block that has popped off the last U


# ---------------------------------------------------------------- pieces
def mix(a, b, t=0.5):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def mini_block(im, x, y, s, color):
    """One toy block, s art px square: lit top/left, shaded bottom/right, a highlight pixel."""
    hi, light, base, dark, darker = ui.BLOCKS[color]
    ui.rect(im, x, y, s, s, base)
    ui.hline(im, x, y, s, light)
    ui.vline(im, x, y, s, light)
    ui.hline(im, x + 1, y + s - 1, s - 1, dark)
    ui.vline(im, x + s - 1, y + 1, s - 1, dark)
    if s >= 6:
        ui.hline(im, x + 1, y + s - 2, s - 2, mix(base, dark))
    ui.px(im, x, y, hi)
    if s >= 5:
        ui.px(im, x + 1, y + 1, hi)


def outline_alpha(im, color, grow=1):
    """A copy of `im`'s silhouette grown by `grow` px (4-neighbour), filled with `color`."""
    w, h = im.size
    a = im.getchannel("A").load()
    out = ui.img(w, h)
    for y in range(h):
        for x in range(w):
            if a[x, y] > 0:
                for dy in range(-grow, grow + 1):
                    for dx in range(-grow, grow + 1):
                        if abs(dx) + abs(dy) <= grow + (1 if grow > 1 else 0):
                            ui.px(out, x + dx, y + dy, color)
    return out


def stamp(dst, src, x, y):
    dst.alpha_composite(src, (x, y))


def block_word(word, s, gap_cells=1, skip=None):
    """Toy block letters with an ink outline and a chunky ink drop shadow."""
    cells_w = sum(len(LETTERS[c][0]) for c in word) + gap_cells * (len(word) - 1)
    w, h = cells_w * s, 7 * s
    face = ui.img(w, h)
    x0 = 0
    for li, ch in enumerate(word):
        rows = LETTERS[ch]
        for ry, row in enumerate(rows):
            for rx, c in enumerate(row):
                if c == "#" and (li, rx, ry) != skip:
                    mini_block(face, x0 + rx * s, ry * s, s, COLORS[li % len(COLORS)])
        x0 += (len(rows[0]) + gap_cells) * s
    return face


def inked(face, shadow=(2, 3)):
    """Face + 1 px ink outline + an offset ink shadow, on a padded canvas (pad 1 + shadow)."""
    pad = 1
    w, h = face.width + 2 * pad + shadow[0], face.height + 2 * pad + shadow[1]
    base = ui.img(w, h)
    body = ui.img(w, h)
    stamp(body, face, pad, pad)
    ring = outline_alpha(body, ui.INK)
    stamp(base, ring, shadow[0], shadow[1])
    stamp(base, ring, 0, 0)
    stamp(base, body, 0, 0)
    return base


def text(word, size, color):
    """Blockhead text rendered without anti-aliasing (size 10 = 1 art px per font pixel)."""
    f = ImageFont.truetype(FONT, size)
    l, t, r, b = f.getbbox(word)
    im = ui.img(r - l + 2, b - t + 2)
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    d.text((1 - l, 1 - t), word, font=f, fill=color)
    return im


def marquee(w, h, label_size, word="ARCADE", label_cx=None):
    """Plum marquee plate with a brass rim, chaser bulbs, and ARCADE."""
    im = ui.img(w, h)
    ui.fill_shape(im, 0, 0, w, h, 3, ui.INK)
    ui.fill_shape(im, 1, 1, w - 2, h - 2, 3, ui.SUN_D)
    ui.fill_shape(im, 1, 1, w - 2, h - 3, 3, ui.SUN)
    ui.hline(im, 4, 1, w - 8, ui.SUN_L)
    ui.fill_shape(im, 3, 3, w - 6, h - 6, 2, ui.INK)
    ui.fill_shape(im, 4, 4, w - 8, h - 8, 2, ui.PLUM_D)
    ui.hline(im, 5, 4, w - 10, ui.PLUM)
    # Chaser bulbs on the brass rim (every 6 px along top and bottom).
    for i, bx in enumerate(range(6, w - 5, 6)):
        c = ui.WHITE if i % 2 == 0 else ui.CREAM_D
        for by in (1, h - 3):
            ui.px(im, bx, by, c)
            ui.px(im, bx + 1, by, c)
            ui.px(im, bx, by + 1, ui.SUN_L)
            ui.px(im, bx + 1, by + 1, ui.SUN_L)
    label = text(word, label_size, ui.CREAM)
    shadow = text(word, label_size, ui.PINK_D)
    lx = (w - label.width) // 2 if label_cx is None else label_cx - label.width // 2
    ly = (h - label.height) // 2
    stamp(im, shadow, lx, ly + max(1, label_size // 10))
    stamp(im, label, lx, ly)
    return im


def pop_burst(im, cx, cy, s, color):
    """The popped block over a comic starburst, with a spray of chips."""
    import math
    star = ui.img(im.width, im.height)
    d = ImageDraw.Draw(star)
    for r_out, r_in, c in ((s * 1.9 + 1, s * 1.05 + 1, ui.INK), (s * 1.9, s * 1.05, ui.SUN), (s * 1.3, s * 0.8, ui.SUN_L)):
        pts = []
        for i in range(20):
            r = r_out if i % 2 == 0 else r_in
            a = i * math.pi / 10 - math.pi / 2 + 0.12
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
        d.polygon(pts, fill=c)
    stamp(im, star, 0, 0)
    blk = ui.img(s, s)
    mini_block(blk, 0, 0, s, color)
    stamp(im, inked(blk, (1, 2)), cx - s // 2 - 1, cy - s // 2 - 1)
    hi, light, base, dark, darker = ui.BLOCKS[color]
    k = max(1, s // 4)
    for (dx, dy, c, n) in ((-2 * s - 2, s, light, k + 1), (2 * s + 1, s + 2, base, k + 1), (-s, -2 * s - 1, ui.CREAM, k),
                           (2 * s + 2, -s, light, k), (-2 * s - 1, -s, ui.CREAM, k), (s // 2, 2 * s + 2, ui.WHITE, k)):
        ui.rect(im, cx + dx - 1, cy + dy - 1, n + 2, n + 2, ui.INK)
        ui.rect(im, cx + dx, cy + dy, n, n, c)


def lockup(s=8, with_pops=True):
    """POPS pointing at BURU over the ARCADE marquee, with the pop. Returns an art-pixel image."""
    li, rx, ry = POPPED
    letters = inked(block_word(WORD, s, skip=POPPED))
    pops = gen_helper.draw_pops(4) if with_pops else None  # frame 4: pointing right, at the logo
    left = pops.width + 3 if pops else 0
    mh = 26
    margin = 22  # room for the pop above and to the right
    w = left + letters.width + margin + 4
    h = margin + letters.height - 6 + mh + 2
    im = ui.img(w, h)
    lx, ly = left + 2, margin
    plate_top = ly + letters.height - 6
    px0 = 10 if pops else lx + 9
    mw = lx + letters.width - 11 - px0
    # POPS stands behind the marquee like a shopkeeper behind his sign.
    if pops:
        stamp(im, pops, 0, plate_top + 3 - pops.height)
    stamp(im, marquee(mw, mh, 20, label_cx=lx + (letters.width - 2) // 2 - px0), px0, plate_top)
    stamp(im, letters, lx, ly)
    # Popped block: flying up and right from its slot at the top of the last U.
    col = sum(len(LETTERS[c][0]) + 1 for c in WORD[:li]) + rx
    slot = (lx + 1 + col * s + s // 2, ly + 1 + ry * s + s // 2)
    pop_burst(im, slot[0] + s + 6, slot[1] - s - 4, s, COLORS[li])
    return im


def mark():
    """Square mark: POPS (happy) on a plum tile with a bulb rim, over a BURU ARCADE banner."""
    n = 92
    im = ui.img(n, n)
    ui.fill_shape(im, 0, 0, n, n, 6, ui.INK)
    ui.fill_shape(im, 1, 1, n - 2, n - 2, 6, ui.SUN_D)
    ui.fill_shape(im, 1, 1, n - 2, n - 3, 6, ui.SUN)
    ui.fill_shape(im, 4, 4, n - 8, n - 8, 4, ui.INK)
    ui.fill_shape(im, 5, 5, n - 10, n - 10, 4, ui.PLUM_D)
    ui.fill_shape(im, 14, 10, n - 28, n - 36, 8, ui.PLUM)  # stepped glow behind POPS
    ui.fill_shape(im, 20, 16, n - 40, n - 48, 8, ui.PLUM_L)
    for i, bx in enumerate(range(9, n - 8, 6)):
        c = ui.WHITE if i % 2 == 0 else ui.CREAM_D
        ui.rect(im, bx, 2, 2, 1, c)
        ui.rect(im, bx, n - 3, 2, 1, c)
        ui.rect(im, 2, bx, 1, 2, c)
        ui.rect(im, n - 3, bx, 1, 2, c)
    pops = gen_helper.draw_pops(6)
    stamp(im, pops, (n - pops.width) // 2, 8)
    # Two little blocks popping off his afro.
    pop_burst(im, 76, 17, 4, "blue")
    blk = ui.img(4, 4)
    mini_block(blk, 0, 0, 4, "red")
    stamp(im, inked(blk, (1, 1)), 12, 22)
    plate = marquee(n - 6, 18, 10, "BURU ARCADE")
    stamp(im, plate, 3, n - 18 - 6)
    return im


def header():
    """1500x220 at 2x: a plum night with drifting toy blocks, marquee bulbs, the lockup centered."""
    w, h = 750, 110
    im = ui.img(w, h)
    ui.rect(im, 0, 0, w, h, ui.PLUM_DD)
    for i in range(6):  # stepped glow behind the logo, ellipse bands
        e = ui.img(w, h)
        rx, ry = 300 - i * 42, 70 - i * 9
        ImageDraw.Draw(e).ellipse((w // 2 - rx, h // 2 - ry, w // 2 + rx, h // 2 + ry), fill=mix(ui.PLUM_DD, ui.PLUM, 0.18 + i * 0.1))
        stamp(im, e, 0, 0)
    import random
    rng = random.Random(7)
    names = ["red", "orange", "yellow", "green", "blue", "purple"]
    for i in range(46):
        s = rng.choice((4, 5, 6, 8))
        x, y = rng.randrange(0, w - s), rng.randrange(6, h - s - 6)
        if abs(x + s / 2 - w / 2) < 250:
            continue  # keep the logo area clean
        blk = ui.img(s, s)
        mini_block(blk, 0, 0, s, names[i % 6])
        faded = Image.blend(Image.new("RGBA", blk.size, ui.PLUM_DD), blk, 0.35)
        faded.putalpha(blk.getchannel("A"))
        stamp(im, faded, x, y)
    for i, bx in enumerate(range(2, w, 8)):  # marquee bulb strips
        c = ui.SUN_L if i % 2 == 0 else ui.SUN_D
        ui.rect(im, bx, 1, 3, 2, c)
        ui.rect(im, bx, h - 3, 3, 2, c)
    logo = lockup()
    stamp(im, logo, (w - logo.width) // 2, (h - logo.height) // 2)
    return im.resize((w * 2, h * 2), Image.NEAREST)


def big(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def main():
    os.makedirs(OUT, exist_ok=True)
    open(os.path.join(OUT, ".gdignore"), "w").close()
    logo = lockup()
    big(logo, 4).save(os.path.join(OUT, "buru_arcade_logo.png"))
    big(logo, 8).save(os.path.join(OUT, "buru_arcade_logo_8x.png"))
    m = mark()
    big(m, 4).save(os.path.join(OUT, "buru_arcade_mark.png"))
    big(m, 2).save(os.path.join(OUT, "steam_avatar_184.png"))
    header().save(os.path.join(OUT, "steam_header_1500x220.png"))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
