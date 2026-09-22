"""Generates BLOCKMANIA's pixel-art UI kit (original art, authored as code).

Run:  python tools/art/gen_ui.py
Out:  assets/ui/*.png  (drawn at 1x "art pixels", exported at SCALE x with nearest-neighbour)

Style: "Midnight Toybox Arcade" - chunky candy-plastic parts with ink outlines, chamfered
corners, bevel light from the top-left, brass rivets, cream paper. One art pixel = 4 screen
pixels at 1920x1080. 9-slice margins listed in NINE are in *exported* pixels.
"""
import json
import os
from PIL import Image

SCALE = 4
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "ui")

# ---------------------------------------------------------------- palette
INK = (26, 16, 38, 255)
INK_SOFT = (26, 16, 38, 110)
CLEAR = (0, 0, 0, 0)
PLUM_DD = (33, 22, 49, 255)
PLUM_D = (45, 30, 67, 255)
PLUM = (63, 43, 94, 255)
PLUM_L = (92, 66, 130, 255)
PLUM_LL = (128, 98, 173, 255)
CREAM = (255, 243, 219, 255)
CREAM_D = (239, 214, 176, 255)
CREAM_DD = (205, 168, 124, 255)
SUN_L = (255, 236, 150, 255)
SUN = (255, 204, 61, 255)
SUN_D = (222, 150, 34, 255)
SUN_DD = (158, 96, 22, 255)
MINT_L = (140, 244, 190, 255)
MINT = (61, 214, 145, 255)
MINT_D = (30, 150, 100, 255)
MINT_DD = (18, 96, 66, 255)
PINK_L = (255, 150, 170, 255)
PINK = (255, 77, 109, 255)
PINK_D = (200, 40, 80, 255)
PINK_DD = (130, 22, 58, 255)
SKY_L = (160, 216, 255, 255)
SKY = (77, 170, 255, 255)
SKY_D = (40, 110, 214, 255)
SKY_DD = (26, 66, 150, 255)
LILAC = (179, 136, 255, 255)
WHITE = (255, 255, 255, 255)

BLOCKS = {
    # name: (highlight, light, base, dark, darker)
    "red": ((255, 196, 202, 255), (255, 128, 140, 255), (246, 72, 92, 255), (196, 38, 64, 255), (138, 22, 48, 255)),
    "orange": ((255, 226, 186, 255), (255, 178, 104, 255), (255, 142, 52, 255), (212, 96, 22, 255), (150, 62, 14, 255)),
    "yellow": ((255, 250, 204, 255), (255, 234, 120, 255), (255, 206, 52, 255), (220, 156, 22, 255), (160, 106, 14, 255)),
    "green": ((200, 255, 222, 255), (128, 236, 172, 255), (58, 206, 124, 255), (28, 152, 92, 255), (16, 102, 64, 255)),
    "blue": ((200, 228, 255, 255), (122, 188, 255, 255), (60, 142, 255, 255), (34, 92, 214, 255), (22, 58, 150, 255)),
    "purple": ((236, 214, 255, 255), (206, 160, 255, 255), (166, 98, 255, 255), (118, 58, 214, 255), (80, 34, 150, 255)),
    "stone": ((210, 204, 222, 255), (160, 152, 178, 255), (120, 112, 138, 255), (86, 80, 104, 255), (58, 53, 74, 255)),
}

NINE = {}


def img(w, h):
    return Image.new("RGBA", (w, h), CLEAR)


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def rect(im, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            px(im, xx, yy, c)


def hline(im, x, y, w, c):
    rect(im, x, y, w, 1, c)


def vline(im, x, y, h, c):
    rect(im, x, y, 1, h, c)


def chamfer_mask(w, h, cut):
    """Returns a predicate: is (x, y) inside a w*h rectangle with `cut`-pixel stepped corners."""
    def inside(x, y):
        if x < 0 or y < 0 or x >= w or y >= h:
            return False
        dx = min(x, w - 1 - x)
        dy = min(y, h - 1 - y)
        return dx + dy >= cut
    return inside


def fill_shape(im, ox, oy, w, h, cut, c):
    inside = chamfer_mask(w, h, cut)
    for y in range(h):
        for x in range(w):
            if inside(x, y):
                px(im, ox + x, oy + y, c)


def outline_shape(im, ox, oy, w, h, cut, c):
    """1-px outline on the border pixels of the chamfered shape."""
    inside = chamfer_mask(w, h, cut)
    for y in range(h):
        for x in range(w):
            if inside(x, y) and not all(inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px(im, ox + x, oy + y, c)


def save(name, im, nine=None):
    os.makedirs(OUT, exist_ok=True)
    big = im.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST)
    big.save(os.path.join(OUT, name + ".png"))
    if nine is not None:
        NINE[name] = [v * SCALE for v in nine]


# ---------------------------------------------------------------- blocks (22x22)
def block(name):
    hi, light, base, dark, darker = BLOCKS[name]
    n = 22
    im = img(n, n)
    fill_shape(im, 0, 0, n, n, 3, INK)
    fill_shape(im, 1, 1, n - 2, n - 2, 3, base)
    # bevel ring: top/left light, bottom/right dark (3 px deep)
    inside = chamfer_mask(n - 2, n - 2, 3)
    for y in range(n - 2):
        for x in range(n - 2):
            if not inside(x, y):
                continue
            d_top, d_left = y, x
            d_bottom, d_right = (n - 3) - y, (n - 3) - x
            m = min(d_top, d_left, d_bottom, d_right)
            if m >= 3:
                continue
            if d_top == m or d_left == m:
                c = light if d_top <= d_left else light
                if d_top == m and d_top < d_bottom:
                    c = light
                if d_left == m and d_left < d_right and d_top > d_left:
                    c = light
            else:
                c = darker if d_bottom == m and m == 0 else dark
            px(im, 1 + x, 1 + y, c)
    # face gradient: top half slightly lighter
    for y in range(4, 10):
        for x in range(4, n - 4):
            if im.getpixel((x, y)) == base:
                px(im, x, y, tuple(min(255, int(a + (b - a) * 0.28)) for a, b in zip(base[:3], light[:3])) + (255,))
    # inner rim line
    for x in range(4, n - 4):
        px(im, x, n - 5, dark)
    # glint
    rect(im, 4, 4, 3, 1, hi)
    rect(im, 4, 5, 1, 2, hi)
    px(im, 8, 4, hi)
    # sparkle speck
    px(im, n - 7, 6, light)
    return im


def block_stone():
    im = block("stone")
    hi, light, base, dark, darker = BLOCKS["stone"]
    # cracks and a bolt: boss-placed fixed cell
    for i, (x, y) in enumerate([(6, 9), (7, 10), (8, 10), (9, 11), (10, 12), (11, 12), (12, 13), (13, 14)]):
        px(im, x, y, darker)
    for x, y in [(14, 7), (15, 8), (15, 9), (16, 10)]:
        px(im, x, y, darker)
    rect(im, 9, 15, 4, 1, dark)
    return im


# ---------------------------------------------------------------- material overlays (22x22)
def overlay_chrome():
    im = img(22, 22)
    silver = (235, 242, 255, 200)
    for k in range(3):
        for i in range(10):
            x = 4 + k * 6 + i // 2
            y = 16 - i
            px(im, x, y, silver)
    outline_shape(im, 1, 1, 20, 20, 3, (222, 232, 245, 255))
    return im


def overlay_neon():
    im = img(22, 22)
    outline_shape(im, 0, 0, 22, 22, 3, (255, 92, 214, 255))
    outline_shape(im, 3, 3, 16, 16, 2, (120, 250, 255, 255))
    return im


def overlay_gold():
    im = img(22, 22)
    outline_shape(im, 1, 1, 20, 20, 3, SUN)
    outline_shape(im, 2, 2, 18, 18, 3, SUN_D)
    fill_shape(im, 7, 7, 8, 8, 2, SUN_DD)
    fill_shape(im, 7, 7, 7, 7, 2, SUN)
    rect(im, 9, 9, 2, 2, SUN_L)
    return im


def overlay_glass():
    im = img(22, 22)
    glare = (255, 255, 255, 230)
    for i in range(11):
        px(im, 5 + i, 16 - i, glare)
        px(im, 6 + i, 16 - i, (255, 255, 255, 120))
    for i in range(5):
        px(im, 12 + i, 17 - i, (255, 255, 255, 160))
    outline_shape(im, 1, 1, 20, 20, 3, (214, 246, 255, 255))
    return im


def overlay_prism():
    im = img(22, 22)
    bands = [BLOCKS[c][1] for c in ("red", "orange", "yellow", "green", "blue", "purple")]
    for i, c in enumerate(bands):
        for y in (15, 16):
            for x in range(4 + i * 2 + (i // 1) * 0, 6 + i * 2):
                px(im, x + 1, y, c)
    outline_shape(im, 1, 1, 20, 20, 3, (255, 255, 255, 200))
    return im


def overlay_mask():
    """Glass tint mask: marks the face area (used as alpha in-engine)."""
    im = img(22, 22)
    fill_shape(im, 1, 1, 20, 20, 3, WHITE)
    return im


LETTERS = {
    "E": ["###", "#..", "##.", "#..", "###"],
    "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "M": ["#.#", "###", "###", "#.#", "#.#"],
}


def stamp_badge(letter, color, dark):
    im = img(9, 9)
    fill_shape(im, 0, 0, 9, 9, 2, INK)
    fill_shape(im, 1, 1, 7, 7, 2, color)
    hline(im, 2, 1, 4, WHITE)
    hline(im, 2, 7, 5, dark)
    for y, row in enumerate(LETTERS[letter]):
        for x, ch in enumerate(row):
            if ch == "#":
                px(im, 3 + x, 2 + y, INK)
    return im


# ---------------------------------------------------------------- panels (9-slice)
def plate(face, light, dark, rim_dark, rivets=True, size=24, cut=3):
    """Chunky enamel plate: ink outline, bevel, 2-px bottom lip, brass rivets."""
    s = size
    im = img(s, s + 2)
    # drop shadow lip
    fill_shape(im, 0, 2, s, s, cut, INK_SOFT)
    fill_shape(im, 0, 0, s, s, cut, INK)
    fill_shape(im, 1, 1, s - 2, s - 2, cut, face)
    inside = chamfer_mask(s - 2, s - 2, cut)
    for y in range(s - 2):
        for x in range(s - 2):
            if not inside(x, y):
                continue
            if y == 0 or (x == 0 and y < s - 4):
                px(im, 1 + x, 1 + y, light)
            elif y >= s - 4:
                px(im, 1 + x, 1 + y, rim_dark)
            elif x == s - 3:
                px(im, 1 + x, 1 + y, dark)
    if rivets:
        # Rivets must sit fully inside the 9-slice corners (margins 7/7/7/9) or they stretch.
        for rx, ry in [(3, 3), (s - 5, 3), (3, s - 5), (s - 5, s - 5)]:
            rect(im, rx, ry, 2, 2, SUN_D)
            px(im, rx, ry, SUN_L)
    return im


def inset(face, shadow, light):
    """Recessed well: dark top/left inner shadow, light bottom lip."""
    s = 20
    im = img(s, s)
    fill_shape(im, 0, 0, s, s, 2, INK)
    fill_shape(im, 1, 1, s - 2, s - 2, 2, face)
    hline(im, 2, 1, s - 4, shadow)
    hline(im, 2, 2, s - 4, shadow)
    vline(im, 1, 2, s - 4, shadow)
    hline(im, 2, s - 2, s - 4, light)
    return im


def paper():
    """Cream receipt paper; top edge straight, bottom edge zig-zag torn (tiles horizontally)."""
    w, h = 12, 24
    im = img(w, h)
    rect(im, 0, 0, w, h - 3, CREAM)
    rect(im, 0, 0, w, 1, CREAM_D)
    for x in range(w):
        t = x % 4
        depth = [0, 1, 2, 1][t]
        for y in range(h - 3, h - 3 + (2 - depth) + 1):
            px(im, x, y, CREAM)
        px(im, x, h - 3 + (2 - depth) + 1, CREAM_DD)
    return im


def button(face_l, face, face_d, side, pressed=False, disabled=False):
    w, h = 20, 14
    im = img(w, h)
    top = 1 if pressed else 0
    depth = 1 if pressed else 3
    if disabled:
        face_l, face, face_d, side = PLUM_L, PLUM, PLUM, PLUM_D
    # side (depth)
    fill_shape(im, 0, top + depth, w, h - 3 - top + 0, 2, INK)
    fill_shape(im, 1, top + depth, w - 2, h - 4 - top, 2, side)
    # face
    fill_shape(im, 0, top, w, h - 3, 2, INK)
    fill_shape(im, 1, top + 1, w - 2, h - 5, 2, face)
    hline(im, 3, top + 1, w - 6, face_l)
    hline(im, 2, top + 2, 1, face_l)
    hline(im, 3, top + h - 5, w - 6, face_d)
    return im


def card_frame(border, border_l, border_d, gem):
    """Joker card: cream body, colored border with notched corners, a gem at the top."""
    w, h = 32, 44
    im = img(w, h + 2)
    fill_shape(im, 0, 2, w, h, 3, INK_SOFT)
    fill_shape(im, 0, 0, w, h, 3, INK)
    fill_shape(im, 1, 1, w - 2, h - 2, 3, border)
    hline(im, 3, 1, w - 6, border_l)
    vline(im, 1, 3, h - 6, border_l)
    hline(im, 3, h - 2, w - 6, border_d)
    vline(im, w - 2, 3, h - 6, border_d)
    fill_shape(im, 3, 3, w - 6, h - 6, 2, INK)
    fill_shape(im, 4, 4, w - 8, h - 8, 2, CREAM)
    hline(im, 5, h - 5, w - 10, CREAM_D)
    # gem on the top edge
    fill_shape(im, w // 2 - 3, 0, 6, 5, 1, INK)
    fill_shape(im, w // 2 - 2, 1, 4, 3, 1, gem)
    px(im, w // 2 - 1, 1, WHITE)
    return im


def rack_frame(border, border_l, border_d):
    """Slim card for the Joker rack: cream body, 2-px colored rim with bevel, notched corners."""
    s = 20
    im = img(s, s + 1)
    fill_shape(im, 0, 1, s, s, 2, INK_SOFT)
    fill_shape(im, 0, 0, s, s, 2, INK)
    fill_shape(im, 1, 1, s - 2, s - 2, 2, border)
    hline(im, 3, 1, s - 6, border_l)
    vline(im, 1, 3, s - 6, border_l)
    hline(im, 3, s - 2, s - 6, border_d)
    vline(im, s - 2, 3, s - 6, border_d)
    fill_shape(im, 3, 3, s - 6, s - 6, 1, INK)
    fill_shape(im, 4, 4, s - 8, s - 8, 1, CREAM)
    hline(im, 4, s - 5, s - 8, CREAM_D)
    return im


def tooltip():
    s = 16
    im = img(s, s)
    fill_shape(im, 0, 0, s, s, 2, INK)
    fill_shape(im, 1, 1, s - 2, s - 2, 2, SUN)
    fill_shape(im, 2, 2, s - 4, s - 4, 2, PLUM_DD)
    return im


def pill(face, light, dark):
    w, h = 12, 9
    im = img(w, h)
    fill_shape(im, 0, 0, w, h, 2, INK)
    fill_shape(im, 1, 1, w - 2, h - 2, 2, face)
    hline(im, 2, 1, w - 4, light)
    hline(im, 2, h - 2, w - 4, dark)
    return im


def cell_empty():
    n = 22
    im = img(n, n)
    rect(im, 0, 0, n, n, (36, 24, 54, 255))
    rect(im, 1, 1, n - 2, n - 2, (44, 30, 66, 255))
    hline(im, 1, 1, n - 2, (30, 20, 46, 255))
    vline(im, 1, 1, n - 2, (30, 20, 46, 255))
    hline(im, 2, n - 2, n - 3, (54, 38, 80, 255))
    rect(im, 10, 10, 2, 2, (58, 42, 86, 255))
    return im


def board_frame():
    """Cabinet frame: 7-px brass rim (room for stamped coordinates), corner bolts, ink lip.
    9-slice margins 10/10/10/12 art px; the grid starts 10 art px (40 screen px) inside."""
    s = 40
    im = img(s, s + 2)
    fill_shape(im, 0, 2, s, s, 5, INK_SOFT)
    fill_shape(im, 0, 0, s, s, 5, INK)
    fill_shape(im, 1, 1, s - 2, s - 2, 5, SUN_D)
    fill_shape(im, 2, 1, s - 4, s - 3, 5, SUN)
    hline(im, 5, 1, s - 10, SUN_L)
    hline(im, 4, 2, s - 8, SUN_L)
    vline(im, 1, 5, s - 10, SUN_L)
    hline(im, 5, s - 2, s - 10, SUN_DD)
    vline(im, s - 2, 5, s - 10, SUN_DD)
    # inner ink lip and recess
    fill_shape(im, 8, 8, s - 16, s - 16, 1, INK)
    fill_shape(im, 9, 9, s - 18, s - 18, 1, PLUM_DD)
    hline(im, 9, 9, s - 18, INK)
    # corner bolts (inside the corner slices)
    for bx, by in [(3, 3), (s - 6, 3), (3, s - 6), (s - 6, s - 6)]:
        fill_shape(im, bx, by, 3, 3, 1, SUN_DD)
        px(im, bx + 1, by + 1, SUN_L)
    return im


# ---------------------------------------------------------------- icons (ASCII art)
ICON_PALETTE = {
    ".": CLEAR, "k": INK, "w": WHITE, "c": CREAM, "C": CREAM_DD,
    "y": SUN_L, "Y": SUN, "o": SUN_D, "O": SUN_DD,
    "p": PINK_L, "P": PINK, "r": PINK_D, "R": PINK_DD,
    "s": SKY_L, "S": SKY, "b": SKY_D, "B": SKY_DD,
    "m": MINT_L, "M": MINT, "g": MINT_D, "G": MINT_DD,
    "l": PLUM_LL, "L": PLUM_L, "u": PLUM, "U": PLUM_D, "v": LILAC,
}

ICONS = {
    "coin": [
        "...kkkkk...",
        "..kyyyyYk..",
        ".kyYYYYYok.",
        "kyYYooOYYok",
        "kyYoYYYOYok",
        "kYYoYyYOYok",
        "kYYoYYYOYok",
        "kYYYOOOYYok",
        ".kYYYYYYok.",
        "..kooooook.",
        "...kkkkk...",
    ],
    "bag": [
        "....kkk....",
        "...kCkCk...",
        "....kCk....",
        "...kkkkk...",
        "..kcccccCk.",
        ".kccccccCCk",
        "kcccccccCCk",
        "kcccccccCCk",
        "kccccccCCCk",
        ".kCCCCCCCk.",
        "..kkkkkkk..",
    ],
    "gear": [
        "....kkk....",
        ".kk.kLk.kk.",
        ".kLkkLkkLk.",
        "..kLLLLLk..",
        "kkkLkkkLkkk",
        "kLLLk.kLLLk",
        "kkkLkkkLkkk",
        "..kLLLLLk..",
        ".kLkkLkkLk.",
        ".kk.kLk.kk.",
        "....kkk....",
    ],
    "refresh": [
        "...kkkkk.k.",
        "..kMMMMMkMk",
        ".kMkkkkkMMk",
        "kMk....kMMk",
        "kMk...kkkkk",
        "kk.........",
        ".........kk",
        "kkkkk...kMk",
        "kMMk....kMk",
        "kMMkkkkkMk.",
        "kMkMMMMMk..",
        ".k.kkkkk...",
    ],
    "flame": [
        ".....k.....",
        "....kPk....",
        "...kPPk.k..",
        "..kPPPkkPk.",
        ".kPPYPPPPk.",
        ".kPYYYPPPk.",
        "kPPYyYYPPPk",
        "kPYYyyYYPPk",
        "kPYyyyyYPPk",
        ".kPYyyyYPk.",
        "..kkkkkkk..",
    ],
    "skull": [
        "..kkkkkkk..",
        ".kcccccccCk",
        "kcccccccccCk",
        "kckkkcckkkCk",
        "kckkkcckkkCk",
        "kcccckkccCCk",
        ".kcccccccCk.",
        "..kckckckk..",
        "..kkkkkkkk..",
    ],
    "star": [
        ".....k.....",
        "....kYk....",
        "....kYk....",
        "kkkkkyYkkkk",
        ".kYYyyYYYk.",
        "..kYyYYYk..",
        "..kYYkYYk..",
        ".kYYk.kYYk.",
        ".kkk...kkk.",
    ],
    "lock": [
        "...kkkkk...",
        "..kLkkkLk..",
        "..kLk.kLk..",
        ".kkkkkkkkk.",
        ".kYYYYYYok.",
        ".kYYkkYYok.",
        ".kYYkkYYok.",
        ".kYYYYYYok.",
        ".kkkkkkkkk.",
    ],
    "chip": [
        "..kkkkkkk..",
        ".kSSwSSSbk.",
        "kSwSSSSSSbk",
        "kSSkkkkkSbk",
        "kwSksssksbk",
        "kSSksssksbk",
        "kSSkkkkkSbk",
        "kSSSSSSwSbk",
        ".kbbSSSbbk.",
        "..kkkkkkk..",
    ],
    "mult": [
        "..kkkkkkk..",
        ".kPPPPPPrk.",
        "kPkkPPPkkrk",
        "kPPkkPkkPrk",
        "kPPPkkkPPrk",
        "kPPPkkkPPrk",
        "kPPkkPkkPrk",
        "kPkkPPPkkrk",
        ".krrrrrrrk.",
        "..kkkkkkk..",
    ],
    "bulb_on": [
        "..kkkkk..",
        ".kyyyYYk.",
        "kyywyYYok",
        "kyYYYYYok",
        "kYYYYYYok",
        ".kYYYYok.",
        "..kLLLk..",
        "..kUUUk..",
        "...kkk...",
    ],
    "bulb_off": [
        "..kkkkk..",
        ".kLLLuuk.",
        "kLLlLuuUk",
        "kLuuuuuUk",
        "kuuuuuuUk",
        ".kuuuuUk.",
        "..kLLLk..",
        "..kUUUk..",
        "...kkk...",
    ],
    "pause": [
        "kkkk.kkkk",
        "kcCk.kcCk",
        "kcCk.kcCk",
        "kcCk.kcCk",
        "kcCk.kcCk",
        "kcCk.kcCk",
        "kkkk.kkkk",
    ],
    "arrow_up": [
        "...k...",
        "..kck..",
        ".kccck.",
        "kkcckkk",
        "..kck..",
        "..kck..",
        "..kkk..",
    ],
    "arrow_down": [
        "..kkk..",
        "..kck..",
        "..kck..",
        "kkcckkk",
        ".kccck.",
        "..kck..",
        "...k...",
    ],
    "tag": [
        "..kkkkkkkk.",
        ".kYYYYYYYok",
        "kYYkYYYYYok",
        "kYYYYYYYYok",
        ".kYYYYYYYok",
        "..kkkkkkkk.",
    ],
    "hand": [
        "...kk......",
        "..kcck.....",
        "..kcck.....",
        "..kcckkkk..",
        "..kcckcckk.",
        "kkkcccccCck",
        "kcckccccCCk",
        ".kccccccCCk",
        "..kccccCCk.",
        "...kkkkkk..",
    ],
    "target": [
        "..kkkkkkk..",
        ".kPPPPPPPk.",
        "kPPkkkkkPPk",
        "kPkcccccKPk".replace("K", "k"),
        "kPkcPPPckPk",
        "kPkcPYPckPk",
        "kPkcPPPckPk",
        "kPkccccckPk",
        "kPPkkkkkPPk",
        ".kPPPPPPPk.",
        "..kkkkkkk..",
    ],
}


def icon(name):
    rows = ICONS[name]
    w = max(len(r) for r in rows)
    im = img(w, len(rows))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            px(im, x, y, ICON_PALETTE.get(ch, CLEAR))
    return im


def main():
    for name in BLOCKS:
        if name != "stone":
            save("block_" + name, block(name))
    save("block_stone", block_stone())
    save("mat_chrome", overlay_chrome())
    save("mat_neon", overlay_neon())
    save("mat_gold", overlay_gold())
    save("mat_glass", overlay_glass())
    save("mat_prism", overlay_prism())
    save("stamp_encore", stamp_badge("E", PINK, PINK_D))
    save("stamp_refund", stamp_badge("R", SKY, SKY_D))
    save("stamp_tip", stamp_badge("T", SUN, SUN_D))
    save("stamp_memory", stamp_badge("M", LILAC, PLUM_L))
    save("cell_empty", cell_empty())
    save("panel_plate", plate(PLUM, PLUM_L, PLUM_D, PLUM_DD), [7, 7, 7, 9])
    save("panel_plate_plain", plate(PLUM, PLUM_L, PLUM_D, PLUM_DD, rivets=False), [5, 5, 5, 7])
    save("panel_sun", plate(SUN, SUN_L, SUN_D, SUN_DD, rivets=False), [5, 5, 5, 7])
    save("panel_boss", plate((120, 30, 58, 255), PINK_D, PINK_DD, (80, 16, 40, 255)), [7, 7, 7, 9])
    save("panel_inset", inset(PLUM_DD, INK, PLUM), [4, 4, 4, 4])
    save("panel_paper", paper(), [3, 3, 3, 6])
    save("panel_tooltip", tooltip(), [4, 4, 4, 4])
    save("board_frame", board_frame(), [10, 10, 10, 12])
    for key, cols in {
        "sun": (SUN_L, SUN, SUN_D, SUN_DD),
        "mint": (MINT_L, MINT, MINT_D, MINT_DD),
        "pink": (PINK_L, PINK, PINK_D, PINK_DD),
        "sky": (SKY_L, SKY, SKY_D, SKY_DD),
        "plum": (PLUM_LL, PLUM_L, PLUM, PLUM_D),
    }.items():
        save("btn_%s_normal" % key, button(*cols), [4, 3, 4, 5])
        save("btn_%s_hover" % key, button(tuple(min(255, v + 30) for v in cols[0][:3]) + (255,),
                                           tuple(min(255, v + 22) for v in cols[1][:3]) + (255,), cols[2], cols[3]), [4, 3, 4, 5])
        save("btn_%s_pressed" % key, button(*cols, pressed=True), [4, 3, 4, 5])
    save("btn_disabled", button(*(SUN_L, SUN, SUN_D, SUN_DD), disabled=True), [4, 3, 4, 5])
    save("card_common", card_frame(PLUM_L, PLUM_LL, PLUM_D, CREAM_DD), [6, 7, 6, 8])
    save("card_uncommon", card_frame(SKY_D, SKY, SKY_DD, SKY_L), [6, 7, 6, 8])
    save("card_rare", card_frame(SUN_D, SUN, SUN_DD, PINK), [6, 7, 6, 8])
    save("card_item", card_frame(PINK_D, PINK, PINK_DD, MINT_L), [6, 7, 6, 8])
    save("card_tool", card_frame(MINT_D, MINT, MINT_DD, SUN_L), [6, 7, 6, 8])
    save("rack_common", rack_frame(PLUM_L, PLUM_LL, PLUM_D), [5, 5, 5, 6])
    save("rack_uncommon", rack_frame(SKY_D, SKY, SKY_DD), [5, 5, 5, 6])
    save("rack_rare", rack_frame(SUN_D, SUN, SUN_DD), [5, 5, 5, 6])
    save("rack_item", rack_frame(PINK_D, PINK, PINK_DD), [5, 5, 5, 6])
    save("pill_sun", pill(SUN, SUN_L, SUN_D), [3, 3, 3, 3])
    save("pill_pink", pill(PINK, PINK_L, PINK_D), [3, 3, 3, 3])
    save("pill_sky", pill(SKY, SKY_L, SKY_D), [3, 3, 3, 3])
    save("pill_mint", pill(MINT, MINT_L, MINT_D), [3, 3, 3, 3])
    save("pill_plum", pill(PLUM_L, PLUM_LL, PLUM), [3, 3, 3, 3])
    for name in ICONS:
        save("icon_" + name, icon(name))
    with open(os.path.join(OUT, "nine.json"), "w") as f:
        json.dump(NINE, f, indent=1)
    print("wrote", len(os.listdir(OUT)), "files to", OUT)


if __name__ == "__main__":
    main()
