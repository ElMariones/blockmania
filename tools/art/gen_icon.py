"""Generates BLOCKMANIA's app icon (original art, authored as code).

Run:  python tools/art/gen_icon.py
Out:  icon.png (256 px, the Godot project / window icon) and icon.ico (16-256 px, the Windows
      executable icon), both at the repository root.

Design: a chamfered plum toy tile with a brass rim and a chunky "B" built from toy blocks, one
color per row (the logo's candy palette). The 32-px master is pixel art scaled by whole numbers;
16 px gets its own simplified drawing so it stays readable in the taskbar and file lists.
"""
import os
from PIL import Image

import gen_ui as ui

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

B_GLYPH = ["#####.", "##..##", "##..##", "#####.", "##..##", "##..##", "#####."]
ROW_COLORS = ["red", "orange", "yellow", "green", "blue", "purple", "red"]


def tile(n, cut, rim):
    """Chamfered ink-outlined tile: brass rim, plum face with a lit top edge."""
    im = ui.img(n, n)
    ui.fill_shape(im, 0, 0, n, n, cut, ui.INK)
    ui.fill_shape(im, 1, 1, n - 2, n - 2, cut, ui.SUN_D)
    ui.fill_shape(im, 1, 1, n - 2, n - 3, cut, ui.SUN)
    ui.hline(im, cut + 1, 1, n - 2 * cut - 2, ui.SUN_L)
    ui.vline(im, 1, cut + 1, n - 2 * cut - 3, ui.SUN_L)
    inner = rim + 1
    ui.fill_shape(im, inner, inner, n - 2 * inner, n - 2 * inner, max(1, cut - rim), ui.INK)
    ui.fill_shape(im, inner + 1, inner + 1, n - 2 * inner - 2, n - 2 * inner - 2, max(1, cut - rim - 1), ui.PLUM_D)
    ui.hline(im, inner + 2, inner + 1, n - 2 * inner - 4, ui.PLUM)
    return im


def master32():
    """32x32: 3-px blocks (lit corner, shaded edge) forming the B, with a drop shadow."""
    im = tile(32, 4, 3)
    bs = 3
    ox, oy = 7, 5
    for ry, row in enumerate(B_GLYPH):
        hi, light, base, dark, darker = ui.BLOCKS[ROW_COLORS[ry]]
        for rx, ch in enumerate(row):
            if ch != "#":
                continue
            x, y = ox + rx * bs, oy + ry * bs
            ui.rect(im, x + 1, y + 1, bs, bs, ui.INK)  # shadow
    for ry, row in enumerate(B_GLYPH):
        hi, light, base, dark, darker = ui.BLOCKS[ROW_COLORS[ry]]
        for rx, ch in enumerate(row):
            if ch != "#":
                continue
            x, y = ox + rx * bs, oy + ry * bs
            ui.rect(im, x, y, bs, bs, base)
            ui.px(im, x, y, hi)
            ui.px(im, x + 1, y, light)
            ui.px(im, x, y + 1, light)
            ui.px(im, x + 2, y + 2, dark)
            ui.px(im, x + 2, y + 1, dark)
            ui.px(im, x + 1, y + 2, dark)
    # A sparkle on the rim.
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
        ui.px(im, 26 + dx, 5 + dy, ui.WHITE if (dx, dy) == (0, 0) else ui.SUN_L)
    return im


def small16():
    """16x16: 2-px blocks, flat colors per row, no shadow: the silhouette must read."""
    im = tile(16, 2, 1)
    ox, oy = 2, 1
    for ry, row in enumerate(B_GLYPH):
        hi, light, base, dark, darker = ui.BLOCKS[ROW_COLORS[ry]]
        for rx, ch in enumerate(row):
            if ch == "#":
                x, y = ox + rx * 2, oy + ry * 2
                ui.rect(im, x, y, 2, 2, base)
                ui.px(im, x, y, light)
    return im


def main():
    m = master32()
    big = {s: m.resize((s, s), Image.NEAREST) for s in (32, 64, 128, 256)}
    big[16] = small16()
    # 48 and 24 are not whole multiples of 32: downsample the 2x/1x drawings smoothly.
    big[48] = m.resize((96, 96), Image.NEAREST).resize((48, 48), Image.LANCZOS)
    big[24] = m.resize((64, 64), Image.NEAREST).resize((24, 24), Image.LANCZOS)
    big[256].save(os.path.join(ROOT, "icon.png"))
    order = [256, 128, 64, 48, 32, 24, 16]
    big[256].save(os.path.join(ROOT, "icon.ico"), format="ICO", sizes=[(s, s) for s in order],
                  append_images=[big[s] for s in order[1:]])
    print("wrote icon.png and icon.ico")


if __name__ == "__main__":
    main()
