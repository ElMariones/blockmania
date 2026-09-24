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
LIL_L = (226, 196, 255, 255)
LIL = (160, 96, 250, 255)
LIL_D = (108, 54, 200, 255)
LIL_DD = (70, 34, 130, 255)
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
    "e": (238, 166, 92, 255), "E": (206, 124, 64, 255), "d": (160, 86, 46, 255), "D": (108, 52, 40, 255),
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
    "brick": [
        "kkkkkkkkkkkk",
        "kppPPkpPPPrk",
        "kPPPrkPPPrrk",
        "kkkkkkkkkkkk",
        "kPrkpPPPrkPk",
        "krrkPPPrrkrk",
        "kkkkkkkkkkkk",
        "kppPPkpPPPrk",
        "kPrrRkPrrRRk",
        "kkkkkkkkkkkk",
    ],
    "eraser": [
        "......kkkk.",
        ".....kppPPk",
        "....kppPPrk",
        "...kppPPrk.",
        "..kssPPrk..",
        ".kssSkrk...",
        "kssSbkk....",
        "kSSbk......",
        ".kkk.......",
    ],
    "hammer": [
        ".kkkkkk....",
        "kllLLLLk...",
        "kLLLLLUk...",
        "kLLLLLUkk..",
        ".kkkkkkCck.",
        "......kCck.",
        ".......kCck",
        ".......kCCk",
        "........kk.",
    ],
    "bucket": [
        ".kkkkkkkkk.",
        "kLkPPPPPkLk",
        "kLkPpPPPkLk",
        ".kLkkkkkLk.",
        ".kccccccCk.",
        ".kcvvvvcCk.",
        ".kccccccCk.",
        "..kccccCk..",
        "..kkkkkkk..",
    ],
    "blueprint": [
        "kkkkkkkkkkk",
        "kSSSSSSSSbk",
        "kSwwwSwwSbk",
        "kSwSSSSwSbk",
        "kSwSwwSwSbk",
        "kSwSSSSSSbk",
        "kSwwwwwwSbk",
        "kSSSSSSSSbk",
        "kbbbbbbbbBk",
        "kkkkkkkkkkk",
    ],
    "crate": [
        "..kkkkkkkkkkkk..",
        ".keeeeeeeeeeeek.",
        "kkkkkkkkkkkkkkkk",
        "kleeeeekyYkeeeuk",
        "kLEEEEEkyokEEEUk",
        "kkkkkyYYYYYokkkk",
        "keEkEyPPPPPoEdDk",
        "keEkEyPcPcPoEdDk",
        "keEkdyrPcProdddk",
        "keEkEkoooookEdDk",
        "klEkEEEEEEEEEduk",
        "kkkkkkkkkkkkkkkk",
    ],
    # Title menu icons: cream/ink so they read on any button color.
    "play": [
        "kk.........",
        "kckk.......",
        "kccckk.....",
        "kccccckk...",
        "kccccccckk.",
        "kccccccccCk",
        "kcccccccCkk",
        "kcccccCkk..",
        "kcccCkk....",
        "kcCkk......",
        "kkk........",
    ],
    "piece": [
        "kkkkkkkkkkkkk",
        "kpPPkyYYksSSk",
        "kPPrkYYOkSSbk",
        "kPrrkYOOkSbbk",
        "kkkkkkkkkkkkk",
        "....kmMMk....",
        "....kMMgk....",
        "....kMggk....",
        "....kkkkk....",
    ],
    "trophy": [
        "kkkkkkkkkkk",
        "kYkyYYYokYk",
        ".kkyYYYokk.",
        "...kYYok...",
        "....kok....",
        "....kYk....",
        "..kkkkkkk..",
        "..kyYYoOk..",
        "..kkkkkkk..",
    ],
    "power": [
        "....kkk....",
        ".kk.kPk.kk.",
        "kPPkkPkkPPk",
        "kPkkkPkkkPk",
        "kPk.kPk.kPk",
        "kPk.kkk.kPk",
        "kPk.....kPk",
        "kPPk...kPrk",
        ".kPPkkkPrk.",
        "..kkrrrkk..",
        "....kkk....",
    ],
    "tomb": [
        "...kkkkk...",
        "..kLLLLLk..",
        ".kLLlkLLUk.",
        ".kLlkkkLUk.",
        ".kLLlkLLUk.",
        ".kLLlkLLUk.",
        ".kLLLLLLUk.",
        ".kLLLLLLUk.",
        "kkkkkkkkkkk",
        "kgggggggggk",
        "kkkkkkkkkkk",
    ],
    "scope": [
        ".....kkkk..",
        "....kssbk..",
        "....kSSk...",
        "...kkSSk...",
        "..kLLkSk...",
        ".kLLLLkk...",
        "kLlLLLLk...",
        "kLLLLLUk...",
        ".kLLLUk....",
        "..kkkk.....",
    ],
    "medal": [
        ".kk.....kk.",
        ".kSk...kPk.",
        "..kSk.kPk..",
        "...kSkPk...",
        "..kkkkkkk..",
        ".kyYYYYYok.",
        "kyYYkYYYYok",
        "kYYkkkYYYok",
        "kYYYkYYYYok",
        ".kYYYYYYok.",
        "..kkkkkkk..",
    ],
    "shield": [
        "kkkkkkkkkkk",
        "kmMMMMMMMgk",
        "kMMMkkMMMgk",
        "kMMkcckMMgk",
        "kMMMkckMMgk",
        ".kMMMkMMgk.",
        ".kMMMMMMgk.",
        "..kMMMMgk..",
        "...kMMgk...",
        "....kgk....",
        ".....k.....",
    ],
    "magnet": [
        ".kkkk.kkkk.",
        ".kPPk.kSSk.",
        ".kccc.kccc.",
        ".kPPk.kSSk.",
        ".kPPkkkSSk.",
        ".kPPPPPSSk.",
        "..kPPPSSk..",
        "...kkkkk...",
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


# ---------------------------------------------------------------- Boss Crate (64x60)
WOOD_HI = (255, 218, 160, 255)
WOOD_L = (238, 166, 92, 255)
WOOD = (206, 124, 64, 255)
WOOD_M = (184, 104, 54, 255)
WOOD_D = (160, 86, 46, 255)
WOOD_DD = (108, 52, 40, 255)

CRATE_SKULL = [
    ".ccccc.",
    "ccccccc",
    "ckkckkc",
    "ckkckkc",
    "cccKccc",
    ".ccccc.",
    ".cKcKc.",
]


def _rivet(im, x, y):
    px(im, x, y, SUN_L)
    px(im, x + 1, y, SUN)
    px(im, x, y + 1, SUN)
    px(im, x + 1, y + 1, SUN_DD)


def _bracket(im, x, y, flip_x, flip_y, arm=8, t=3):
    """L-shaped iron corner cap with a brass rivet. (x, y) is the outer corner."""
    sx = -1 if flip_x else 1
    sy = -1 if flip_y else 1
    cells = set()
    for i in range(arm):
        for j in range(t):
            cells.add((x + sx * i, y + sy * j))
            cells.add((x + sx * j, y + sy * i))
    for cx, cy in cells:
        # Ink rim on the cap's inner edges, light on the face that catches the top-left light.
        ix, iy = (cx - x) * sx, (cy - y) * sy
        inner = (ix == arm - 1 and iy < t) or (iy == arm - 1 and ix < t) \
            or (ix == t - 1 and iy >= t) or (iy == t - 1 and ix >= t)
        if inner:
            px(im, cx, cy, INK)
        elif (not flip_y and iy == 0) or (not flip_x and ix == 0):
            px(im, cx, cy, PLUM_LL)
        elif (flip_y and iy == 0) or (flip_x and ix == 0):
            px(im, cx, cy, PLUM)
        else:
            px(im, cx, cy, PLUM_L)
    _rivet(im, x + sx * 1 - (1 if flip_x else 0), y + sy * 1 - (1 if flip_y else 0))


def _plank(im, x0, x1, y0, h, rng, face=WOOD, light=WOOD_L, dark=WOOD_D):
    """Horizontal plank with a lit top edge, a shaded bottom edge, grain streaks and maybe a knot."""
    for y in range(y0, y0 + h):
        c = light if y == y0 else dark if y == y0 + h - 1 else face
        hline(im, x0, y, x1 - x0 + 1, c)
    for _ in range((x1 - x0) // 7):
        gy = rng.randint(y0 + 1, y0 + h - 2)
        gx = rng.randint(x0 + 1, x1 - 5)
        hline(im, gx, gy, rng.randint(2, 5), dark if rng.random() < 0.7 else light)
    if h >= 6 and rng.random() < 0.55:
        kx = rng.randint(x0 + 4, x1 - 6)
        ky = y0 + h // 2 - 1
        rect(im, kx, ky, 3, 2, dark)
        px(im, kx + 1, ky, WOOD_DD)
        px(im, kx - 1, ky + 1, dark)
        px(im, kx + 3, ky, dark)


def crate_big(crack=False):
    """The Boss Crate: a front-facing wooden crate with a hinged lid, iron corner caps, a
    diagonal brace and a brass hasp holding a pink skull seal. `crack` lifts the lid 2 px with
    light spilling out of the seam (the hover frame)."""
    import random
    rng = random.Random(11)
    W, H = 64, 60
    im = img(W, H)
    lift = 2 if crack else 0
    bx0, bx1, by0, by1 = 4, 59, 24, 55          # body, inclusive
    lx0, lx1 = 3, 60                             # lid overhangs the body by 1 px
    ly0, ly1 = 16 - lift, 23 - lift              # lid front band
    ty0 = 6 - lift                               # lid top face (trapezoid)

    # Ground shadow.
    for y in range(55, 60):
        half = int(30 * (1 - ((y - 57) / 3.2) ** 2) ** 0.5) if abs(y - 57) < 3.2 else 0
        hline(im, 32 - half, y, half * 2, INK_SOFT)

    # ---- body
    rect(im, bx0, by0, bx1 - bx0 + 1, by1 - by0 + 1, INK)
    ix0, ix1 = bx0 + 1, bx1 - 1
    y = by0 + 1
    while y < by1:
        h = min(7, by1 - y)
        _plank(im, ix0, ix1, y, h, rng, WOOD_M, WOOD, WOOD_D)
        y += h
        if y < by1:
            hline(im, ix0, y, ix1 - ix0 + 1, WOOD_DD)
            y += 1
    # Side stiles and the bottom rail (the crate frame).
    for sx0 in (ix0, ix1 - 5):
        rect(im, sx0, by0 + 1, 6, by1 - by0 - 1, WOOD)
        vline(im, sx0, by0 + 1, by1 - by0 - 1, WOOD_L)
        vline(im, sx0 + 5, by0 + 1, by1 - by0 - 1, WOOD_D)
        for _ in range(4):
            gx = rng.randint(sx0 + 1, sx0 + 4)
            gy = rng.randint(by0 + 3, by1 - 8)
            vline(im, gx, gy, rng.randint(2, 4), WOOD_D)
    vline(im, ix0 + 6, by0 + 1, by1 - by0 - 1, INK)
    vline(im, ix1 - 6, by0 + 1, by1 - by0 - 1, INK)
    rect(im, ix0 + 7, by1 - 6, ix1 - ix0 - 13, 6, WOOD)
    hline(im, ix0 + 7, by1 - 7, ix1 - ix0 - 13, INK)
    hline(im, ix0 + 7, by1 - 6, ix1 - ix0 - 13, WOOD_L)
    hline(im, ix0 + 7, by1 - 1, ix1 - ix0 - 13, WOOD_D)
    for _ in range(5):
        hline(im, rng.randint(ix0 + 8, ix1 - 12), rng.randint(by1 - 5, by1 - 3), rng.randint(2, 4), WOOD_D)
    # Diagonal brace from bottom-left to top-right between the stiles.
    x_a, x_b = ix0 + 7, ix1 - 7
    y_a, y_b = by1 - 8, by0 + 2
    for x in range(x_a, x_b + 1):
        t = (x - x_a) / (x_b - x_a)
        yc = round(y_a + (y_b - y_a) * t)
        top, bot = yc - 3, yc + 3
        for yy in range(max(top, by0 + 1), min(bot, by1 - 7) + 1):
            c = WOOD
            if yy == top or yy == bot:
                c = INK
            elif yy == top + 1:
                c = WOOD_HI
            elif yy == top + 2:
                c = WOOD_L
            elif yy == bot - 1:
                c = WOOD_D
            px(im, x, yy, c)
    for _ in range(6):
        gx = rng.randint(x_a + 3, x_b - 6)
        gy = round(y_a + (y_b - y_a) * (gx - x_a) / (x_b - x_a))
        for k in range(rng.randint(2, 4)):
            yy = round(y_a + (y_b - y_a) * (gx + k - x_a) / (x_b - x_a))
            px(im, gx + k, yy + (gy - gy), WOOD_D)
    # Nail heads where the brace meets the frame.
    for nx, ny in ((x_a + 2, y_a), (x_b - 3, y_b + 2)):
        px(im, nx, ny, PLUM_LL)
        px(im, nx + 1, ny, PLUM)
        px(im, nx + 1, ny + 1, INK)
    # Soft ambient shade under the lid lip.
    for x in range(ix0, ix1 + 1):
        c = im.getpixel((x, by0 + 1))
        if c != INK:
            px(im, x, by0 + 1, WOOD_DD if c in (WOOD, WOOD_M, WOOD_L, WOOD_HI) else c)

    # ---- light spilling from the gap (hover frame)
    if crack:
        rect(im, bx0 + 1, ly1 + 1, bx1 - bx0 - 1, lift, SUN_L)
        hline(im, bx0 + 4, ly1 + 1, bx1 - bx0 - 7, WHITE)
        # Warm light washing over the first plank row.
        for x in range(bx0 + 1, bx1):
            c = im.getpixel((x, by0 + 1))
            if c != INK:
                px(im, x, by0 + 1, SUN)

    # ---- lid top face: trapezoid seen from slightly above, planks running left to right
    depth = ly0 - ty0
    for r in range(depth):
        inset = round(5 * (1 - r / max(1, depth - 1)))
        x0, x1 = lx0 + inset, lx1 - inset
        yy = ty0 + r
        hline(im, x0, yy, x1 - x0 + 1, INK)
        if r == 0:
            continue
        seam = r in (depth // 2,)
        c = WOOD_DD if seam else WOOD_HI if r in (1, depth // 2 + 1) else WOOD_L
        hline(im, x0 + 1, yy, x1 - x0 - 1, c)
    for _ in range(9):
        r = rng.randint(2, depth - 2)
        if r == depth // 2:
            continue
        inset = round(5 * (1 - r / max(1, depth - 1)))
        gx = rng.randint(lx0 + inset + 2, lx1 - inset - 6)
        hline(im, gx, ty0 + r, rng.randint(2, 5), WOOD)

    # ---- lid front band
    rect(im, lx0, ly0, lx1 - lx0 + 1, ly1 - ly0 + 1, INK)
    _plank(im, lx0 + 1, lx1 - 1, ly0 + 1, ly1 - ly0 - 1, rng, WOOD_L, WOOD_HI, WOOD)
    hline(im, lx0 + 1, ly1 - 1, lx1 - lx0 - 1, WOOD_D)

    # ---- iron corner caps
    _bracket(im, lx0, ly0, False, False, arm=6, t=3)
    _bracket(im, lx1, ly0, True, False, arm=6, t=3)
    _bracket(im, bx0, by1, False, True)
    _bracket(im, bx1, by1, True, True)

    # ---- brass hasp on the lid, lock plate on the body
    cx = W // 2
    hx0, hx1 = cx - 4, cx + 3
    rect(im, hx0, ly0 - 1, hx1 - hx0 + 1, (ly1 - ly0) + 5, INK)
    rect(im, hx0 + 1, ly0, hx1 - hx0 - 1, (ly1 - ly0) + 3, SUN)
    vline(im, hx0 + 1, ly0, (ly1 - ly0) + 3, SUN_L)
    vline(im, hx1 - 1, ly0, (ly1 - ly0) + 3, SUN_D)
    _rivet(im, cx - 1, ly0 + 1)
    # Lock plate: a chamfered brass plate with a round pink wax seal and an original skull.
    pw, ph = 20, 19
    px0, py0 = cx - pw // 2, by0 + 2
    fill_shape(im, px0, py0, pw, ph, 3, INK)
    fill_shape(im, px0 + 1, py0 + 1, pw - 2, ph - 2, 3, SUN)
    hline(im, px0 + 3, py0 + 1, pw - 6, SUN_L)
    vline(im, px0 + 1, py0 + 3, ph - 6, SUN_L)
    hline(im, px0 + 3, py0 + ph - 2, pw - 6, SUN_DD)
    vline(im, px0 + pw - 2, py0 + 3, ph - 6, SUN_D)
    for rx, ry in ((px0 + 2, py0 + 2), (px0 + pw - 4, py0 + 2), (px0 + 2, py0 + ph - 4), (px0 + pw - 4, py0 + ph - 4)):
        px(im, rx + 1, ry + 1, SUN_DD)
        px(im, rx, ry, SUN_L)
    # Seal: a stepped disc, darker on the lower right, with drips of wax.
    scx, scy, rad = cx - 0.5, py0 + ph / 2 - 0.5, 6.6
    for yy in range(int(scy - rad) - 1, int(scy + rad) + 2):
        for xx in range(int(scx - rad) - 1, int(scx + rad) + 2):
            d = ((xx - scx) ** 2 + (yy - scy) ** 2) ** 0.5
            if d <= rad + 0.5:
                if d > rad - 0.6:
                    c = INK
                elif (xx - scx) + (yy - scy) > 4.2:
                    c = PINK_D
                elif (xx - scx) + (yy - scy) < -5.2:
                    c = PINK_L
                else:
                    c = PINK
                px(im, xx, yy, c)
    px(im, int(scx + rad) - 1, int(scy + rad), INK)
    px(im, int(scx + rad) - 1, int(scy + rad) + 1, PINK_DD)
    for sy, row in enumerate(CRATE_SKULL):
        for sx, ch in enumerate(row):
            if ch == "c":
                px(im, cx - 4 + sx, int(scy) - 3 + sy, CREAM)
            elif ch == "k":
                px(im, cx - 4 + sx, int(scy) - 3 + sy, INK)
            elif ch == "K":
                px(im, cx - 4 + sx, int(scy) - 3 + sy, PINK_DD)
    # Glints on the brass and the lid.
    px(im, px0 + 4, py0 + 3, WHITE)
    px(im, lx0 + 8, ly0 + 1, WHITE)
    px(im, lx0 + 9, ly0 + 1, WOOD_HI)

    if crack:
        # Sparkles escaping the lid.
        # Sparkles escaping past the lid: little 4-point stars.
        for sx, sy, c in ((1, ly1 - 3, SUN_L), (62, ly1 - 5, WHITE), (60, ty0 - 1, SUN_L), (4, ty0 + 1, WHITE)):
            px(im, sx, sy, c)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                px(im, sx + dx, sy + dy, SUN)
    return im


def main():
    for name in BLOCKS:
        if name != "stone":
            save("block_" + name, block(name))
    save("block_stone", block_stone())
    # Material faces, Endless block styles and stamp badges: tools/art/gen_finishes.py
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
    save("card_legendary", card_frame(LIL, LIL_L, LIL_D, SUN_L), [6, 7, 6, 8])
    save("rack_common", rack_frame(PLUM_L, PLUM_LL, PLUM_D), [5, 5, 5, 6])
    save("rack_uncommon", rack_frame(SKY_D, SKY, SKY_DD), [5, 5, 5, 6])
    save("rack_rare", rack_frame(SUN_D, SUN, SUN_DD), [5, 5, 5, 6])
    save("rack_item", rack_frame(PINK_D, PINK, PINK_DD), [5, 5, 5, 6])
    save("rack_legendary", rack_frame(LIL, LIL_L, LIL_D), [5, 5, 5, 6])
    save("pill_sun", pill(SUN, SUN_L, SUN_D), [3, 3, 3, 3])
    save("pill_pink", pill(PINK, PINK_L, PINK_D), [3, 3, 3, 3])
    save("pill_sky", pill(SKY, SKY_L, SKY_D), [3, 3, 3, 3])
    save("pill_mint", pill(MINT, MINT_L, MINT_D), [3, 3, 3, 3])
    save("pill_plum", pill(PLUM_L, PLUM_LL, PLUM), [3, 3, 3, 3])
    save("pill_lilac", pill(LIL, LIL_L, LIL_D), [3, 3, 3, 3])
    for name in ICONS:
        save("icon_" + name, icon(name))
    save("crate_big", crate_big())
    save("crate_big_open", crate_big(crack=True))
    with open(os.path.join(OUT, "nine.json"), "w") as f:
        json.dump(NINE, f, indent=1)
    print("wrote", len(os.listdir(OUT)), "files to", OUT)


if __name__ == "__main__":
    main()
