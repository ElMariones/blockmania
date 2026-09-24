"""Builds the README images in docs/media/ from raw in-game captures and the game's own
code-drawn art (no external or generated-image art).

    python tools/readme/shoot_all.py        # raw captures -> docs/media/raw/ (needs Godot)
    python tools/readme/build_media.py      # compose, crop and compress -> docs/media/

Inputs: docs/media/raw/*.png, assets/ui/cards/*.png (portraits), assets/ui/finish_*.png
(block finishes), assets/fonts/blockhead*.ttf. Pillow only.
"""
import json, os, re
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, "docs/media/raw")
OUT = os.path.join(ROOT, "docs/media")
FONT = os.path.join(ROOT, "assets/fonts/blockhead.ttf")
BOLD = os.path.join(ROOT, "assets/fonts/blockhead_bold.ttf")

INK = (26, 16, 38)
PLUM_DD = (33, 22, 49)
PLUM_D = (45, 30, 67)
PLUM = (63, 43, 94)
PLUM_L = (92, 66, 130)
CREAM = (255, 243, 219)
SUN = (255, 204, 61)
SUN_D = (222, 150, 34)
MINT = (61, 214, 145)
PINK = (255, 77, 109)
SKY = (77, 170, 255)
LILAC = (179, 136, 255)
DIM = (185, 166, 214)
RARITY = {"COMMON": ("COMMON", DIM), "UNCOMMON": ("UNCOMMON", SKY), "RARE": ("RARE", PINK), "LEGENDARY": ("LEGENDARY", LILAC)}
BLOCKS = [(236, 64, 90), (255, 140, 40), (255, 204, 61), (61, 214, 145), (77, 150, 255), (170, 110, 255)]


def font(size, bold=True):
    return ImageFont.truetype(BOLD if bold else FONT, size)


def text(d, xy, s, size, fill, bold=True, outline=0, anchor="la"):
    d.fontmode = "1"  # Blockhead is a pixel font: no antialiasing
    f = font(size, bold)
    if outline:
        for dx in range(-outline, outline + 1, max(1, outline // 2)):
            for dy in range(-outline, outline + 1, max(1, outline // 2)):
                d.text((xy[0] + dx, xy[1] + dy), s, font=f, fill=INK, anchor=anchor)
    d.text(xy, s, font=f, fill=fill, anchor=anchor)


def block(d, x, y, s, c):
    """A chunky toy block like the game's (face, light top edge, dark bottom lip)."""
    dark = tuple(int(v * 0.62) for v in c)
    light = tuple(min(255, int(v * 1.25 + 30)) for v in c)
    d.rectangle([x, y, x + s - 1, y + s - 1], fill=INK)
    d.rectangle([x + 2, y + 2, x + s - 3, y + s - 3], fill=dark)
    d.rectangle([x + 2, y + 2, x + s - 3, y + s - 3 - s // 6], fill=c)
    d.rectangle([x + 2 + s // 8, y + 2 + s // 10, x + s - 3 - s // 8, y + 2 + s // 10 + max(2, s // 10)], fill=light)


def plate(w, h, fill=PLUM_D, rim=PLUM_L):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 6, w - 1, h - 1], fill=INK)
    d.rectangle([0, 0, w - 1, h - 7], fill=INK)
    d.rectangle([4, 4, w - 5, h - 11], fill=rim)
    d.rectangle([8, 8, w - 9, h - 15], fill=fill)
    for cx, cy in ((12, 12), (w - 18, 12), (12, h - 21), (w - 18, h - 21)):
        d.rectangle([cx, cy, cx + 5, cy + 5], fill=SUN_D)
    return im


def screenshots():
    """Raw 1920x1080 captures -> 1600-wide JPEGs (a good size/quality point for READMEs)."""
    for name in sorted(os.listdir(RAW)):
        if not name.endswith(".png") or name == "banner.png" or name.startswith("gif_"):
            continue
        im = Image.open(os.path.join(RAW, name)).convert("RGB")
        im = im.resize((1600, 900), Image.LANCZOS)
        im.save(os.path.join(OUT, "shot_" + name.replace(".png", ".jpg")), quality=86, optimize=True, progressive=True)


def banner():
    src = Image.open(os.path.join(RAW, "banner.png")).convert("RGB")
    im = src.crop((60, 96, 1860, 476)).resize((1800, 380))
    band = Image.new("RGB", (1800, 96), PLUM_DD)
    d = ImageDraw.Draw(band)
    d.rectangle([0, 0, 1799, 5], fill=INK)
    tags = ["ROGUELIKE", "BLOCK PUZZLE", "69 JOKERS", "BOSSES", "PIXEL ARCADE", "WINDOWS"]
    f = font(30)
    widths = [d.textlength(t, font=f) + 48 for t in tags]
    x = (1800 - (sum(widths) + 14 * (len(tags) - 1))) / 2
    colors = [SUN, MINT, PINK, SKY, LILAC, SUN]
    for t, w, c in zip(tags, widths, colors):
        d.rectangle([x, 22, x + w, 76], fill=INK)
        d.rectangle([x + 3, 25, x + w - 3, 70], fill=c)
        text(d, (x + w / 2, 48), t, 30, INK, anchor="mm")
        x += w + 14
    out = Image.new("RGB", (1800, 476))
    out.paste(im, (0, 0))
    out.paste(band, (0, 380))
    out.save(os.path.join(OUT, "banner.jpg"), quality=90, optimize=True, progressive=True)


def header(slug, title, color=SUN, blocks=(0, 1, 2)):
    """Section header: pixel title with ink outline between toy blocks. Transparent, so it
    reads on GitHub's light and dark themes."""
    f = font(60)
    tmp = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    tw = int(tmp.textlength(title, font=f))
    s = 30
    w = tw + 2 * (3 * (s + 6) + 30) + 20
    im = Image.new("RGBA", (w, 96), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i, b in enumerate(blocks):
        block(d, 10 + i * (s + 6), 33 - (i % 2) * 12, s, BLOCKS[b])
        block(d, w - 10 - s - i * (s + 6), 33 - (i % 2) * 12, s, BLOCKS[(b + 3) % 6])
    text(d, (w // 2 + 3, 51), title, 60, INK, anchor="mm")
    text(d, (w // 2, 48), title, 60, color, outline=4, anchor="mm")
    im.save(os.path.join(OUT, "h_%s.png" % slug), optimize=True)


def jokers():
    cards = json.load(open(os.path.join(ROOT, "assets/ui/cards/cards.json")))["jokers"]
    sheet = Image.open(os.path.join(ROOT, "assets/ui/cards/jokers.png")).convert("RGBA")
    src = open(os.path.join(ROOT, "game/content/jokers.gd"), encoding="utf-8").read()
    defs = re.findall(r'\{"id": "([a-z_]+)", "name": "([^"]+)", "rarity": ([A-Z]+)', src)
    order = {"LEGENDARY": 0, "RARE": 1, "UNCOMMON": 2, "COMMON": 3}
    defs.sort(key=lambda t: (order[t[2]], t[1]))
    cols, tile, gap, px = 12, 112, 12, 5
    rows = (len(defs) + cols - 1) // cols
    w = cols * tile + (cols - 1) * gap + 80
    h = rows * tile + (rows - 1) * gap + 190
    im = plate(w, h)
    d = ImageDraw.Draw(im)
    text(d, (w // 2, 58), "THE JOKER RACK", 60, SUN, outline=4, anchor="mm")
    counts = {r: sum(1 for t in defs if t[2] == r) for r in order}
    legend = "   ".join("%d %s" % (counts[r], RARITY[r][0]) for r in ("LEGENDARY", "RARE", "UNCOMMON", "COMMON"))
    text(d, (w // 2, 112), legend, 20, DIM, anchor="mm")
    for i, (jid, name, rarity) in enumerate(defs):
        x = 40 + (i % cols) * (tile + gap)
        y = 140 + (i // cols) * (tile + gap)
        rim = RARITY[rarity][1]
        d.rectangle([x, y, x + tile - 1, y + tile - 1], fill=INK)
        d.rectangle([x + 4, y + 4, x + tile - 5, y + tile - 5], fill=rim)
        d.rectangle([x + 8, y + 8, x + tile - 9, y + tile - 9], fill=CREAM)
        if jid in cards:
            row = cards[jid]
            icon = sheet.crop((0, row * 16, 16, row * 16 + 16)).resize((16 * px, 16 * px), Image.NEAREST)
            im.alpha_composite(icon, (x + (tile - 16 * px) // 2, y + (tile - 16 * px) // 2))
    im.save(os.path.join(OUT, "jokers.png"), optimize=True)


def finishes():
    meta = json.load(open(os.path.join(ROOT, "assets/ui/finishes.json")))
    cell = int(meta["cell"])
    names = {"glass": "STAINED GLASS", "crystal": "CRYSTAL", "neon": "NEON", "gold": "GOLD", "marble": "MARBLE",
             "cyberpunk": "CIRCUIT", "wood": "TOY WOOD", "candy": "CANDY", "lava": "LAVA", "ice": "ICE",
             "chrome": "CHROME", "prism": "PRISM", "aurora": "AURORA", "starfall": "STARFALL"}
    ids = [k for k in names if os.path.exists(os.path.join(ROOT, "assets/ui/finish_%s.png" % k))]
    cols, tile = 7, 200
    w = cols * tile + 80
    h = 150 + ((len(ids) + cols - 1) // cols) * (tile + 20) + 20
    im = plate(w, h)
    d = ImageDraw.Draw(im)
    text(d, (w // 2, 58), "BLOCK FINISHES", 60, SUN, outline=4, anchor="mm")
    text(d, (w // 2, 110), "every face is animated pixel art drawn by code", 20, DIM, anchor="mm")
    for i, fid in enumerate(ids):
        sheet = Image.open(os.path.join(ROOT, "assets/ui/finish_%s.png" % fid)).convert("RGBA")
        x = 40 + (i % cols) * tile
        y = 140 + (i // cols) * (tile + 20)
        # Four blocks in a 2x2 cluster, each a different color and frame, like a piece on the board.
        for k, (cx, cy) in enumerate(((0, 0), (1, 0), (0, 1), (1, 1))):
            color = (i * 2 + k) % 6
            frame = (k * 5) % max(1, sheet.width // cell)
            face = sheet.crop((frame * cell, color * cell, frame * cell + cell, color * cell + cell)).resize((64, 64), Image.NEAREST)
            im.alpha_composite(face, (x + 36 + cx * 64, y + cy * 64))
        text(d, (x + tile // 2, y + 160), names[fid], 20, CREAM, anchor="mm")
    im.save(os.path.join(OUT, "finishes.png"), optimize=True)


def badges():
    cards = json.load(open(os.path.join(ROOT, "assets/ui/cards/cards.json")))["achievements"]
    sheet = Image.open(os.path.join(ROOT, "assets/ui/cards/achievements.png")).convert("RGBA")
    ids = [k for k in sorted(cards, key=lambda k: cards[k]) if not k.startswith("_")][:24]
    size = sheet.width // 8
    px, tile = 5, 96
    w = 12 * tile + 80
    im = plate(w, 2 * tile + 170)
    d = ImageDraw.Draw(im)
    text(d, (w // 2, 58), "60 ACHIEVEMENTS", 60, SUN, outline=4, anchor="mm")
    text(d, (w // 2, 108), "five pages of medals, ten of them secret", 20, DIM, anchor="mm")
    for i, aid in enumerate(ids):
        row = cards[aid]
        icon = sheet.crop((0, row * size, size, row * size + size)).resize((size * px, size * px), Image.NEAREST)
        x = 40 + (i % 12) * tile + (tile - size * px) // 2
        y = 132 + (i // 12) * tile + (tile - size * px) // 2
        im.alpha_composite(icon, (x, y))
    im.save(os.path.join(OUT, "badges.png"), optimize=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    screenshots()
    banner()
    for slug, title, color, b in (("about", "ABOUT THE GAME", SUN, (0, 1, 2)), ("features", "FEATURES", MINT, (3, 4, 5)),
                                  ("gallery", "SCREENSHOTS", SKY, (4, 5, 0)), ("modes", "MORE WAYS TO PLAY", PINK, (1, 2, 3)),
                                  ("craft", "HOW IT IS MADE", LILAC, (5, 0, 1)), ("tech", "TECH STACK", SUN, (2, 3, 4)),
                                  ("dev", "FOR DEVELOPERS", MINT, (0, 2, 4)), ("status", "STATUS", PINK, (1, 3, 5))):
        header(slug, title, color, b)
    jokers()
    finishes()
    badges()
    print("media written to", OUT)
