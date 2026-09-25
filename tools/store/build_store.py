"""Builds the Steam store description media in store/steam/ (English, Spanish, Simplified Chinese).

    python tools/store/capture.py       # real-game captures -> build/store/ (needs Godot)
    python tools/store/build_store.py   # compose -> store/steam/

Images with words come in one file per Steam language (suffix _english / _spanish / _schinese,
so Steam groups them); screenshots and clips are shared. Latin text uses the game's Blockhead
font; Chinese uses Microsoft YaHei Bold rendered at 16 px without antialiasing and scaled by
whole numbers, so both read as the same chunky pixel type. Pillow + ffmpeg (libx264, libvpx-vp9).
"""
import glob, json, os, re, shutil, subprocess, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "tools/readme"))
from build_media import BLOCKS, CREAM, DIM, INK, LILAC, MINT, PINK, PLUM_D, PLUM_DD, PLUM_L, SKY, SUN, SUN_D, block, plate  # noqa: E402

RAW = os.path.join(ROOT, "build/store/raw")
FRAMES = os.path.join(ROOT, "build/store/frames")
OUT = os.path.join(ROOT, "store/steam")
IMG = os.path.join(OUT, "images")
SHOTS = os.path.join(OUT, "screenshots")
LANGS = ("english", "spanish", "schinese")
W = 1600  # description images: wide enough to stay sharp in Steam's 780 px column on HiDPI
FFMPEG = shutil.which("ffmpeg") or "C:/ffmpeg/bin/ffmpeg.exe"

LATIN = os.path.join(ROOT, "assets/fonts/blockhead_bold.ttf")
LATIN_REG = os.path.join(ROOT, "assets/fonts/blockhead.ttf")
CJK = "C:/Windows/Fonts/msyhbd.ttc"

# Every word drawn into an image, per language.
T = {
    "english": {
        "tags": ["ROGUELIKE", "BLOCK PUZZLE", "70 JOKERS", "BOSS FIGHTS", "PIXEL ARCADE"],
        "tagline": "PLACE BLOCKS. CLEAR LINES. BREAK THE MACHINE.",
        "h_how": "HOW IT PLAYS", "h_features": "FEATURES", "h_modes": "MORE WAYS TO PLAY",
        "h_options": "PLAY YOUR WAY",
        "jokers": "70 JOKERS", "rarity": ["LEGENDARY", "RARE", "UNCOMMON", "COMMON"],
        "finishes": "BLOCK FINISHES", "finishes_sub": "every face is animated pixel art",
        "fin": ["STAINED GLASS", "CRYSTAL", "NEON", "GOLD", "MARBLE", "CIRCUIT", "TOY WOOD", "CANDY", "LAVA",
                "ICE", "CHROME", "PRISM", "AURORA", "STARFALL"],
        "badges": "60 ACHIEVEMENTS", "badges_sub": "five pages of medals, ten of them secret",
        "loop": ["PLACE", "CLEAR", "SCORE", "SHOP"],
        "loop_sub": ["3 pieces, 8x8 board", "rows and columns", "Chips x Mult", "Jokers and upgrades"],
    },
    "spanish": {
        "tags": ["ROGUELIKE", "PUZLE DE BLOQUES", "70 COMODINES", "JEFES FINALES", "ARCADE PIXEL"],
        "tagline": "COLOCA BLOQUES. LIMPIA LÍNEAS. ROMPE LA MÁQUINA.",
        "h_how": "CÓMO SE JUEGA", "h_features": "CARACTERÍSTICAS", "h_modes": "MÁS FORMAS DE JUGAR",
        "h_options": "JUEGA A TU MANERA",
        "jokers": "70 COMODINES", "rarity": ["LEGENDARIOS", "RAROS", "POCO COMUNES", "COMUNES"],
        "finishes": "ACABADOS DE BLOQUE", "finishes_sub": "cada cara es pixel art animado",
        "fin": ["VIDRIERA", "CRISTAL", "NEÓN", "ORO", "MÁRMOL", "CIRCUITO", "MADERA", "CARAMELO", "LAVA",
                "HIELO", "CROMO", "PRISMA", "AURORA", "ESTRELLAS"],
        "badges": "60 LOGROS", "badges_sub": "cinco páginas de medallas, diez de ellas secretas",
        "loop": ["COLOCA", "LIMPIA", "PUNTÚA", "COMPRA"],
        "loop_sub": ["3 piezas, tablero 8x8", "filas y columnas", "Fichas x Multi", "comodines y mejoras"],
    },
    "schinese": {
        "tags": ["ROGUELIKE", "方块拼图", "70张小丑牌", "首领战", "像素街机"],
        "tagline": "放置方块 · 消除整行 · 打爆机器",
        "h_how": "玩法", "h_features": "游戏特色", "h_modes": "更多玩法", "h_options": "随心设置",
        "jokers": "70张小丑牌", "rarity": ["传说", "稀有", "罕见", "普通"],
        "finishes": "方块材质", "finishes_sub": "每一面都是动态像素画",
        "fin": ["彩绘玻璃", "水晶", "霓虹", "黄金", "大理石", "电路", "玩具木", "糖果", "熔岩",
                "寒冰", "镀铬", "棱镜", "极光", "流星"],
        "badges": "60项成就", "badges_sub": "五页奖章，其中十个是隐藏成就",
        "loop": ["放置", "消除", "计分", "商店"],
        "loop_sub": ["三块拼图，8x8棋盘", "整行与整列", "筹码 x 倍率", "小丑牌与升级"],
    },
}
FIN_IDS = ["glass", "crystal", "neon", "gold", "marble", "cyberpunk", "wood", "candy", "lava", "ice", "chrome",
           "prism", "aurora", "starfall"]


def glyphs(s, lang, px, bold=True):
    """Text as a 1-bit mask at pixel size `px` (Blockhead: multiples of 10; CJK: 16 px glyphs scaled
    to about the same cap height)."""
    if lang == "schinese":
        f, native, k = ImageFont.truetype(CJK, 16), 16, max(1, round(px / 16))
    else:
        f, native, k = ImageFont.truetype(LATIN if bold else LATIN_REG, 10), 10, max(1, px // 10)
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    l, t, r, b = probe.textbbox((0, 0), s, font=f)
    m = Image.new("L", (r - l + 2, native * 2), 0)
    d = ImageDraw.Draw(m)
    d.fontmode = "1"
    d.text((1 - l, native // 2), s, font=f, fill=255)
    bb = m.getbbox() or (0, 0, 1, 1)
    # Keep a stable baseline box: crop x to ink, y to the line box.
    m = m.crop((bb[0], native // 2 + t - 1, bb[2], native // 2 + b + 1))
    return m.resize((m.width * k, m.height * k), Image.NEAREST)


def draw_text(im, xy, s, lang, px, fill, outline=0, shadow=0, anchor="mm", bold=True):
    m = glyphs(s, lang, px, bold)
    pad = outline + shadow
    w, h = m.width + 2 * pad, m.height + 2 * pad
    x, y = xy
    x = {"l": x, "m": x - w // 2, "r": x - w}[anchor[0]]
    y = {"t": y, "m": y - h // 2, "b": y - h}[anchor[1]]
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    big = Image.new("L", (w, h), 0)
    big.paste(m, (pad, pad))
    if shadow:
        sh = Image.new("L", (w, h), 0)
        sh.paste(big.filter(ImageFilter.MaxFilter(2 * outline + 1)) if outline else big, (shadow, shadow))
        layer.paste(INK + (255,), (0, 0), sh)
    if outline:
        layer.paste(INK + (255,), (0, 0), big.filter(ImageFilter.MaxFilter(2 * outline + 1)))
    layer.paste(fill + (255,), (0, 0), big)
    im.alpha_composite(layer, (x, y))
    return w


def text_w(s, lang, px):
    return glyphs(s, lang, px).width


def save_png(im, name):
    im.save(os.path.join(IMG, name), optimize=True)


# ---- Images with words (one per language) -------------------------------------------------------

def banner(lang):
    """The title screen's block logo over a band of genre tags and the tagline."""
    src = Image.open(os.path.join(RAW, "title.png")).convert("RGB")
    logo = src.crop((60, 90, 1860, 350)).resize((W, round(260 * W / 1800)), Image.LANCZOS)
    tr = T[lang]
    band_h = 190
    im = Image.new("RGBA", (W, logo.height + band_h), PLUM_DD + (255,))
    im.paste(logo, (0, 0))
    d = ImageDraw.Draw(im)
    y0 = logo.height
    d.rectangle([0, y0, W, y0 + 5], fill=INK)
    colors = [SUN, MINT, PINK, SKY, LILAC]
    widths = [text_w(t, lang, 30) + 44 for t in tr["tags"]]
    x = (W - (sum(widths) + 14 * (len(widths) - 1))) // 2
    for t, w, c in zip(tr["tags"], widths, colors):
        d.rectangle([x, y0 + 26, x + w, y0 + 84], fill=INK)
        d.rectangle([x + 3, y0 + 29, x + w - 3, y0 + 77], fill=c)
        draw_text(im, (x + w // 2, y0 + 53), t, lang, 30, INK)
        x += w + 14
    draw_text(im, (W // 2, y0 + 140), tr["tagline"], lang, 40, CREAM, outline=4, shadow=3)
    im.convert("RGB").save(os.path.join(IMG, "banner_%s.jpg" % lang), quality=92, optimize=True, progressive=True)


def header(lang, slug, color=SUN, blocks=(0, 1, 2)):
    """Section header, the same width for every section so titles line up: pixel title in an
    ink outline between toy blocks, on a transparent background (reads on Steam's dark page)."""
    title = T[lang]["h_" + slug]
    im = Image.new("RGBA", (W, 130), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    tw = text_w(title, lang, 60)
    s = 36
    for i, b in enumerate(blocks):
        gx = W // 2 - tw // 2 - 60 - (i + 1) * (s + 8)
        block(d, gx, 50 - (i % 2) * 16, s, BLOCKS[b])
        block(d, W - gx - s, 50 - (i % 2) * 16, s, BLOCKS[(b + 3) % 6])
    d.rectangle([0, 120, W, 125], fill=INK)
    d.rectangle([0, 118, W, 121], fill=color)
    draw_text(im, (W // 2, 62), title, lang, 60, color, outline=5, shadow=4)
    save_png(im, "hdr_%s_%s.png" % (slug, lang))


def loop(lang):
    """The core loop as four chunky steps: place, clear, score, shop."""
    tr = T[lang]
    h = 260
    im = Image.new("RGBA", (W, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cw, gap = 340, 46
    x0 = (W - (4 * cw + 3 * gap)) // 2
    colors = [SUN, MINT, PINK, SKY]
    for i in range(4):
        x = x0 + i * (cw + gap)
        im.alpha_composite(plate(cw, 230, fill=PLUM_D, rim=colors[i]), (x, 10))
        draw_text(im, (x + cw // 2, 44), str(i + 1), "english", 30, INK)
        d.rectangle([x + cw // 2 - 20, 26, x + cw // 2 + 20, 62], outline=INK, width=4)
        draw_text(im, (x + cw // 2, 110), tr["loop"][i], lang, 40, colors[i], outline=4)
        draw_text(im, (x + cw // 2, 168), tr["loop_sub"][i], lang, 20, CREAM, bold=False)
        if i < 3:
            ax = x + cw + 8
            d.polygon([(ax, 105), (ax + 26, 125), (ax, 145)], fill=CREAM, outline=INK)
    save_png(im, "loop_%s.png" % lang)


def jokers(lang):
    tr = T[lang]
    cards = json.load(open(os.path.join(ROOT, "assets/ui/cards/cards.json")))["jokers"]
    sheet = Image.open(os.path.join(ROOT, "assets/ui/cards/jokers.png")).convert("RGBA")
    src = open(os.path.join(ROOT, "game/content/jokers.gd"), encoding="utf-8").read()
    defs = re.findall(r'\{"id": "([a-z_]+)", "name": "([^"]+)", "rarity": ([A-Z]+)', src)
    order = ["LEGENDARY", "RARE", "UNCOMMON", "COMMON"]
    rims = {"COMMON": DIM, "UNCOMMON": SKY, "RARE": PINK, "LEGENDARY": LILAC}
    defs.sort(key=lambda t: (order.index(t[2]), t[1]))
    cols, tile, gap, px = 12, 112, 12, 5
    rows = (len(defs) + cols - 1) // cols
    w = cols * tile + (cols - 1) * gap + 80
    h = rows * tile + (rows - 1) * gap + 200
    im = plate(w, h)
    draw_text(im, (w // 2, 60), tr["jokers"], lang, 60, SUN, outline=5, shadow=4)
    counts = [sum(1 for t in defs if t[2] == r) for r in order]
    x = w // 2 - sum(text_w("%d %s" % (n, name), lang, 20) + 60 for n, name in zip(counts, tr["rarity"])) // 2
    for r, n, name in zip(order, counts, tr["rarity"]):
        ImageDraw.Draw(im).rectangle([x, 112, x + 20, 132], fill=rims[r], outline=INK, width=3)
        x += 32
        x += draw_text(im, (x, 122), "%d %s" % (n, name), lang, 20, CREAM, anchor="lm") + 28
    d = ImageDraw.Draw(im)
    for i, (jid, _name, rarity) in enumerate(defs):
        x = 40 + (i % cols) * (tile + gap)
        y = 152 + (i // cols) * (tile + gap)
        d.rectangle([x, y, x + tile - 1, y + tile - 1], fill=INK)
        d.rectangle([x + 4, y + 4, x + tile - 5, y + tile - 5], fill=rims[rarity])
        d.rectangle([x + 8, y + 8, x + tile - 9, y + tile - 9], fill=CREAM)
        if jid in cards:
            row = cards[jid]
            icon = sheet.crop((0, row * 16, 16, row * 16 + 16)).resize((16 * px, 16 * px), Image.NEAREST)
            im.alpha_composite(icon, (x + (tile - 16 * px) // 2, y + (tile - 16 * px) // 2))
    save_png(im, "jokers_%s.png" % lang)


def finishes(lang):
    tr = T[lang]
    meta = json.load(open(os.path.join(ROOT, "assets/ui/finishes.json")))
    cell = int(meta["cell"])
    cols, tile = 7, 210
    w = cols * tile + 80
    h = 150 + 2 * (tile + 20)
    im = plate(w, h)
    draw_text(im, (w // 2, 60), tr["finishes"], lang, 60, SUN, outline=5, shadow=4)
    draw_text(im, (w // 2, 118), tr["finishes_sub"], lang, 20, DIM, bold=False)
    for i, fid in enumerate(FIN_IDS):
        sheet = Image.open(os.path.join(ROOT, "assets/ui/finish_%s.png" % fid)).convert("RGBA")
        x = 40 + (i % cols) * tile
        y = 150 + (i // cols) * (tile + 20)
        for k, (cx, cy) in enumerate(((0, 0), (1, 0), (0, 1), (1, 1))):
            color = (i * 2 + k) % 6
            frame = (k * 5) % max(1, sheet.width // cell)
            face = sheet.crop((frame * cell, color * cell, frame * cell + cell, color * cell + cell)).resize((64, 64), Image.NEAREST)
            im.alpha_composite(face, (x + tile // 2 - 64 + cx * 64, y + cy * 64))
        draw_text(im, (x + tile // 2, y + 150), tr["fin"][i], lang, 20, CREAM)
    save_png(im, "finishes_%s.png" % lang)


def badges(lang):
    tr = T[lang]
    cards = json.load(open(os.path.join(ROOT, "assets/ui/cards/cards.json")))["achievements"]
    sheet = Image.open(os.path.join(ROOT, "assets/ui/cards/achievements.png")).convert("RGBA")
    ids = [k for k in sorted(cards, key=lambda k: cards[k]) if not k.startswith("_")][:24]
    size = sheet.width // 8
    px, tile = 5, 96
    w = 12 * tile + 80
    im = plate(w, 2 * tile + 180)
    draw_text(im, (w // 2, 60), tr["badges"], lang, 60, SUN, outline=5, shadow=4)
    draw_text(im, (w // 2, 116), tr["badges_sub"], lang, 20, DIM, bold=False)
    for i, aid in enumerate(ids):
        row = cards[aid]
        icon = sheet.crop((0, row * size, size, row * size + size)).resize((size * px, size * px), Image.NEAREST)
        x = 40 + (i % 12) * tile + (tile - size * px) // 2
        y = 142 + (i // 12) * tile + (tile - size * px) // 2
        im.alpha_composite(icon, (x, y))
    save_png(im, "badges_%s.png" % lang)


# ---- Shared media (no words of ours) -----------------------------------------------------------

FEATURES = ["round", "clear", "shop", "round_pick", "boss_round", "kits", "bag", "endless"]


def framed(name):
    """A screenshot in a pixel frame, for the description (the game's own UI is English)."""
    shot = Image.open(os.path.join(RAW, name + ".png")).convert("RGB").resize((W - 40, round((W - 40) * 9 / 16)), Image.LANCZOS)
    im = Image.new("RGB", (W, shot.height + 40), INK)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 4, W - 5, im.height - 5], fill=PLUM_L)
    d.rectangle([12, 12, W - 13, im.height - 13], fill=INK)
    im.paste(shot, (20, 20))
    im.save(os.path.join(IMG, "shot_%s.jpg" % name), quality=88, optimize=True, progressive=True)


def steam_screenshots():
    """Full 1920x1080 captures for the store's screenshot carousel (Steam asks for 5 or more)."""
    order = ["round", "clear", "shop", "boss_intro", "boss_round", "kits", "round_pick", "won", "bag",
             "endless", "trophies", "title", "pause"]
    for i, name in enumerate(order, 1):
        Image.open(os.path.join(RAW, name + ".png")).convert("RGB").save(
            os.path.join(SHOTS, "%02d_%s.jpg" % (i, name)), quality=95, optimize=True)


def clip(src, name, start=0, hold=1.6):
    """Slow-motion frames -> real-speed MP4 (H.264) and WEBM (VP9) at 30 fps. Steam plays both in the
    About section; each clip stays under its 12 second limit."""
    files = sorted(glob.glob(os.path.join(FRAMES, src, "f_*.png")))[start:]
    times = [int(os.path.basename(f).split("_")[2].split(".")[0]) * 0.25 / 1000.0 for f in files]
    lst = os.path.join(FRAMES, src, "list.txt")
    with open(lst, "w") as fh:
        for i, f in enumerate(files):
            dur = (times[i + 1] - times[i]) if i + 1 < len(files) else hold
            fh.write("file '%s'\nduration %.4f\n" % (f.replace("\\", "/"), max(dur, 1 / 60)))
        fh.write("file '%s'\n" % files[-1].replace("\\", "/"))
    total = times[-1] - times[0] + hold
    assert total <= 12.0, "%s is %.1f s; Steam allows 12" % (name, total)
    base = [FFMPEG, "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-vf", "fps=30,format=yuv420p"]
    subprocess.run(base + ["-c:v", "libx264", "-crf", "18", "-preset", "slow", "-movflags", "+faststart", "-an",
                           os.path.join(IMG, name + ".mp4")], check=True)
    subprocess.run(base + ["-c:v", "libvpx-vp9", "-crf", "30", "-b:v", "0", "-row-mt", "1", "-an",
                           os.path.join(IMG, name + ".webm")], check=True)
    print(name, "%.1f s" % total)


if __name__ == "__main__":
    for d in (IMG, SHOTS):
        os.makedirs(d, exist_ok=True)
    for lang in LANGS:
        banner(lang)
        loop(lang)
        header(lang, "how", SUN, (0, 1, 2))
        header(lang, "features", MINT, (3, 4, 5))
        header(lang, "modes", PINK, (1, 2, 3))
        header(lang, "options", SKY, (4, 5, 0))
        jokers(lang)
        finishes(lang)
        badges(lang)
    for name in FEATURES:
        framed(name)
    steam_screenshots()
    clip("clip_long", "clip_gameplay")
    clip("clip_boss", "clip_boss", start=2)
    for f in sorted(os.listdir(IMG)):
        print("%-32s %5d KB" % (f, os.path.getsize(os.path.join(IMG, f)) // 1024))
