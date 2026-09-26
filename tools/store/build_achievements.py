"""Builds the Steam achievement kit in store/steam/achievements/, in every language the game ships.

    python tools/store/build_achievements.py

Six Steam achievements, each mirroring one of the game's local achievements (game/content/achievements.gd),
so a local unlock also unlocks on Steam (game/run/steam_bridge.gd). Icons are the game's own medal frames and
16x16 achievement portraits (tools/art/gen_cards.py) at a whole-number scale: 256x256 JPG, full color when
unlocked and grayscale when locked, as Steam recommends. A hidden achievement's locked icon is the "?" medal,
so it spoils nothing. Also writes the localization VDF and a contact sheet.
"""
import json, math, os, re, sys
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
    {"api": "ACH_CROSSROADS", "local": "crossroads", "tier": "bronze", "hidden": False},
    {"api": "ACH_BOSS_BUSTER", "local": "boss_buster", "tier": "bronze", "hidden": False},
    {"api": "ACH_LEGEND_FOUND", "local": "legend_found", "tier": "silver", "hidden": False},
    {"api": "ACH_ARCADE_REGULAR", "local": "arcade_regular", "tier": "silver", "hidden": False},
    {"api": "ACH_BLOCKMANIA", "local": "champion", "tier": "gold", "hidden": False},
    {"api": "ACH_BROKE_THE_MACHINE", "local": "broke_machine", "tier": "legend", "hidden": True},
]
# Steam API language -> the game's locale/<code>.po ("" = the English source). Steam shows English for any
# language missing here; latam and portuguese reuse the game's Spanish and Brazilian Portuguese.
STEAM_LANGS = [("english", ""), ("spanish", "es"), ("latam", "es"), ("french", "fr"), ("italian", "it"),
               ("german", "de"), ("dutch", "nl"), ("polish", "pl"), ("brazilian", "pt_BR"), ("portuguese", "pt_BR"),
               ("japanese", "ja"), ("schinese", "zh_CN"), ("tchinese", "zh_TW")]
sys.path.insert(0, os.path.join(ROOT, "tools/i18n"))
import po  # noqa: E402


def game_texts():
    """{local id: (name, text)} from game/content/achievements.gd, the English source of every language."""
    src = open(os.path.join(ROOT, "game/content/achievements.gd"), encoding="utf-8").read()
    out = {}
    for m in re.finditer(r'\{"id": "([a-z_0-9]+)".*?"name": "((?:[^"\\]|\\.)*)", "text": "((?:[^"\\]|\\.)*)"', src):
        out[m.group(1)] = (m.group(2).replace('\\"', '"'), m.group(3).replace('\\"', '"'))
    return out


def texts(a, code):
    """(name, description) of achievement `a` in the game's language `code` ("" = English). Narrow and no-break
    spaces become plain spaces: Steam's fonts may lack them."""
    name, desc = game_texts()[a["local"]]
    if code:
        tr = {e["id"]: e["str"] for e in po.read(os.path.join(ROOT, "locale", code + ".po"))[1]}
        name, desc = tr.get(name) or name, tr.get(desc) or desc
    plain = lambda t: t.replace("\u202f", " ").replace("\u00a0", " ")
    return plain(name), plain(desc)
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
    for lang, code in STEAM_LANGS:
        lines += ['\t"%s"' % lang, "\t{", '\t\t"Tokens"', "\t\t{"]
        for i, a in enumerate(ACH):
            name, desc = texts(a, code)
            esc = lambda s: s.replace("\\", "\\\\").replace('"', '\\"')
            lines.append('\t\t\t"NEW_ACHIEVEMENT_1_%d_NAME"\t"%s"' % (i, esc(name)))
            lines.append('\t\t\t"NEW_ACHIEVEMENT_1_%d_DESC"\t"%s"' % (i, esc(desc)))
        lines += ["\t\t}", "\t}"]
    lines.append("}")
    with open(os.path.join(OUT, "achievements_loc.vdf"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


def table():
    """texts.md: every achievement in every Steam language, for entering them by hand in Steamworks."""
    out = ["# Steam achievement texts", "", "Generated by `tools/store/build_achievements.py` from the game's own texts",
           "(`game/content/achievements.gd` and `locale/*.po`). Do not edit by hand.", ""]
    for lang, code in STEAM_LANGS:
        out += ["## %s%s" % (lang, " (the game's %s)" % code if code else ""), "", "| API name | Name | Description |", "|---|---|---|"]
        for a in ACH:
            name, desc = texts(a, code)
            out.append("| `%s` | %s | %s |" % (a["api"], name, desc))
        out.append("")
    with open(os.path.join(OUT, "texts.md"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out))


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
    full = [dict(a, texts={lang: texts(a, code) for lang, code in STEAM_LANGS}) for a in ACH]
    with open(os.path.join(OUT, "achievements.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(full, fh, ensure_ascii=False, indent=1)
    table()
    for f in sorted(os.listdir(OUT)):
        print("%-40s %4d KB" % (f, os.path.getsize(os.path.join(OUT, f)) // 1024))
