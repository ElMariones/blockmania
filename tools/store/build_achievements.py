"""Builds the Steam achievement kit in store/steam/achievements/ (English, Spanish, Simplified Chinese).

    python tools/store/build_achievements.py

Six Steam achievements, each mirroring one of the game's local achievements (game/content/achievements.gd),
so a local unlock also unlocks on Steam (game/run/steam_bridge.gd). Icons are the game's own medal frames and
16x16 achievement portraits (tools/art/gen_cards.py) at a whole-number scale: 256x256 JPG, full color when
unlocked and grayscale when locked, as Steam recommends. A hidden achievement's locked icon is the "?" medal,
so it spoils nothing. Also writes the localization VDF and a contact sheet.
"""
import json, math, os, sys
from PIL import Image, ImageDraw, ImageEnhance

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "tools/readme"))
from build_media import INK, LILAC, PLUM_D, PLUM_DD, SUN, SUN_D, DIM, CREAM  # noqa: E402

OUT = os.path.join(ROOT, "store/steam/achievements")
CARDS = os.path.join(ROOT, "assets/ui/cards")
SIZE, SCALE = 256, 10  # a 24 px medal at x10 = 240 px, 8 px margin

# Order matters: Steamworks names localization tokens by creation order (NEW_ACHIEVEMENT_1_0, 1_1, ...).
# `local` is the game's achievement id; `api` is the Steamworks API name (never rename once published).
ACH = [
    {"api": "ACH_CROSSROADS", "local": "crossroads", "tier": "bronze", "hidden": False,
     "english": ("Crossroads", "Clear a row and a column with one placement."),
     "spanish": ("Encrucijada", "Limpia una fila y una columna con una sola colocación."),
     "schinese": ("十字路口", "单次放置同时消除一行和一列。")},
    {"api": "ACH_BOSS_BUSTER", "local": "boss_buster", "tier": "bronze", "hidden": False,
     "english": ("Boss Buster", "Defeat a boss."),
     "spanish": ("Revientajefes", "Derrota a un jefe."),
     "schinese": ("首领克星", "击败一个首领。")},
    {"api": "ACH_LEGEND_FOUND", "local": "legend_found", "tier": "silver", "hidden": False,
     "english": ("Once Upon a Legend", "Own a Legendary Joker."),
     "spanish": ("Érase una leyenda", "Consigue un comodín legendario."),
     "schinese": ("传说的开端", "拥有一张传说小丑牌。")},
    {"api": "ACH_ARCADE_REGULAR", "local": "arcade_regular", "tier": "silver", "hidden": False,
     "english": ("Arcade Regular", "Score 25,000 points in one Endless game."),
     "spanish": ("Habitual del arcade", "Consigue 25.000 puntos en una partida del modo Infinito."),
     "schinese": ("街机常客", "在一局无尽模式中获得25,000分。")},
    {"api": "ACH_BLOCKMANIA", "local": "champion", "tier": "gold", "hidden": False,
     "english": ("BLOCKMANIA!", "Beat the game: win round 12."),
     "spanish": ("¡BLOCKMANIA!", "Pásate el juego: gana la ronda 12."),
     "schinese": ("BLOCKMANIA!", "通关：赢下第12回合。")},
    {"api": "ACH_BROKE_THE_MACHINE", "local": "broke_machine", "tier": "legend", "hidden": True,
     "english": ("Broke the Machine", "Score a single placement past the machine's limit of one quadrillion points."),
     "spanish": ("Máquina rota", "Supera con una sola colocación el límite de la máquina: mil billones de puntos."),
     "schinese": ("机器被玩坏了", "单次放置得分超过机器上限（1,000,000,000,000,000分）。")},
]
LANGS = ("english", "spanish", "schinese")
GLOW = {"bronze": (222, 132, 70), "silver": (190, 200, 230), "gold": SUN, "legend": LILAC}


def sheet_cell(name, row, col=0, cell=16):
    im = Image.open(os.path.join(CARDS, name + ".png")).convert("RGBA")
    return im.crop((col * cell, row * cell, col * cell + cell, row * cell + cell))


def backdrop(color):
    """Plum field with a pixel sunburst in the tier color (8 px pixels, like the game's dithered swirl)."""
    px = 8
    n = SIZE // px
    small = Image.new("RGB", (n, n), PLUM_DD)
    d = ImageDraw.Draw(small)
    c = (n - 1) / 2
    for y in range(n):
        for x in range(n):
            dx, dy = x - c, y - c
            r = (dx * dx + dy * dy) ** 0.5
            ray = (math.atan2(dy, dx) / (2 * math.pi) * 12) % 1.0 < 0.5
            k = max(0.0, 1 - r / (n * 0.62))
            mix = k * (0.55 if ray else 0.3)
            base = PLUM_D if (x + y) % 2 else PLUM_DD
            small.putpixel((x, y), tuple(round(base[i] * (1 - mix) + color[i] * mix) for i in range(3)))
    return small.resize((SIZE, SIZE), Image.NEAREST)


def medal(frame_key, icon):
    cards = json.load(open(os.path.join(CARDS, "cards.json")))
    m = sheet_cell("badges", 0, cards["badges"][frame_key], 24)
    m.alpha_composite(icon, (4, 4))
    return m.resize((24 * SCALE, 24 * SCALE), Image.NEAREST)


def icon_pair(a):
    cards = json.load(open(os.path.join(CARDS, "cards.json")))["achievements"]
    art = sheet_cell("achievements", cards[a["local"]])
    off = (SIZE - 24 * SCALE) // 2
    # Unlocked: the tier medal on a tier-colored burst, with a hard ink shadow under the medal.
    un = backdrop(GLOW[a["tier"]]).convert("RGBA")
    m = medal(a["tier"], art)
    shadow = Image.new("RGBA", m.size, INK + (0,))
    shadow.putalpha(m.getchannel("A").point(lambda v: 150 if v else 0))
    un.alpha_composite(shadow, (off + SCALE // 2, off + SCALE))
    un.alpha_composite(m, (off, off))
    # Locked: grayscale and darker; a hidden one shows the "?" medal instead of its art.
    if a["hidden"]:
        lk = backdrop(DIM).convert("RGBA")
        lm = medal("secret", sheet_cell("achievements", cards["_mystery"]))
        lk.alpha_composite(shadow, (off + SCALE // 2, off + SCALE))
        lk.alpha_composite(lm, (off, off))
    else:
        lk = un.copy()
    lk = ImageEnhance.Brightness(lk.convert("L").convert("RGB")).enhance(0.62)
    return un.convert("RGB"), lk


def vdf():
    """Steam's localization file. Tokens follow Steamworks' own naming for achievements created in this order
    in a new app; compare with the file Steamworks exports before uploading."""
    lines = ['"lang"', "{"]
    for lang in LANGS:
        lines += ['\t"%s"' % lang, "\t{", '\t\t"Tokens"', "\t\t{"]
        for i, a in enumerate(ACH):
            name, desc = a[lang]
            esc = lambda s: s.replace("\\", "\\\\").replace('"', '\\"')
            lines.append('\t\t\t"NEW_ACHIEVEMENT_1_%d_NAME"\t"%s"' % (i, esc(name)))
            lines.append('\t\t\t"NEW_ACHIEVEMENT_1_%d_DESC"\t"%s"' % (i, esc(desc)))
        lines += ["\t\t}", "\t}"]
    lines.append("}")
    with open(os.path.join(OUT, "achievements_loc.vdf"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


def contact(pairs):
    pad = 24
    w = len(pairs) * (SIZE + pad) + pad
    im = Image.new("RGB", (w, 2 * SIZE + 3 * pad), INK)
    for i, (un, lk) in enumerate(pairs):
        im.paste(un, (pad + i * (SIZE + pad), pad))
        im.paste(lk, (pad + i * (SIZE + pad), 2 * pad + SIZE))
    im.save(os.path.join(OUT, "contact_sheet.png"), optimize=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    pairs = []
    for a in ACH:
        un, lk = icon_pair(a)
        un.save(os.path.join(OUT, "%s_unlocked.jpg" % a["api"]), quality=95, optimize=True)
        lk.save(os.path.join(OUT, "%s_locked.jpg" % a["api"]), quality=95, optimize=True)
        pairs.append((un, lk))
    vdf()
    contact(pairs)
    with open(os.path.join(OUT, "achievements.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(ACH, fh, ensure_ascii=False, indent=1)
    for f in sorted(os.listdir(OUT)):
        print("%-40s %4d KB" % (f, os.path.getsize(os.path.join(OUT, f)) // 1024))
