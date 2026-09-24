"""Generates the Refresh lever (original pixel art, authored as code).

Run:  python tools/art/gen_lever.py [contact.png]
Out:  assets/ui/lever.png  one row of 41x44 art-pixel frames, exported at 4x (164x176 each):
      0      housing: plum cabinet plate, brass slot frame, dark slot and pivot (no stick)
      1..5   the stick and its red ball knob, from up (1, at rest) to fully pulled (5); the
             middle frame points at the viewer, so its knob is drawn bigger
      6      the housing with a pink rim, for CONCEDE ROUND
      7      the housing, dimmed and cold, for when no Refresh is left
BMRefreshLever draws the housing, the stick frame for the pull, the lamps (one per Refresh
left) and the labels on top.
"""
import math
import os
import sys
from PIL import Image

import gen_ui as ui

W, H = 41, 44
FRAMES = 8
SLOT_X = 18  # slot is 5 px wide: x 18..22
PIVOT = (20.5, 28.5)
KNOB_Y = [19.0, 23.5, 28.5, 33.5, 38.0]
KNOB_R = [3.6, 3.9, 4.6, 3.9, 3.6]
METAL_L = (214, 208, 226, 255)
METAL = (160, 152, 178, 255)
METAL_D = (86, 80, 104, 255)
KNOB = ((255, 196, 202, 255), (246, 72, 92, 255), (196, 38, 64, 255), (138, 22, 48, 255))


def housing(rim, rim_l, rim_d, rim_dd, cold=False):
    im = ui.img(W, H)
    face, face_l = (ui.PLUM_D, ui.PLUM) if not cold else (ui.PLUM_DD, ui.PLUM_D)
    # Cabinet plate: ink outline, plum face, a lit top edge and two rivets.
    ui.fill_shape(im, 0, 0, W, H, 3, ui.INK)
    ui.fill_shape(im, 1, 1, W - 2, H - 2, 3, face)
    ui.hline(im, 4, 1, W - 8, face_l)
    for x in (4, W - 5):
        ui.px(im, x, H - 4, ui.PLUM_L)
    # Brass frame around the slot (like a gear-shift gate).
    fx, fy, fw, fh = 11, 14, 19, 29
    ui.fill_shape(im, fx, fy, fw, fh, 4, ui.INK)
    ui.fill_shape(im, fx + 1, fy + 1, fw - 2, fh - 2, 4, rim_d)
    ui.fill_shape(im, fx + 1, fy + 1, fw - 2, fh - 3, 4, rim)
    ui.hline(im, fx + 4, fy + 1, fw - 8, rim_l)
    ui.vline(im, fx + 1, fy + 4, fh - 9, rim_l)
    ui.fill_shape(im, fx + 3, fy + 3, fw - 6, fh - 6, 3, ui.INK)
    ui.fill_shape(im, fx + 4, fy + 4, fw - 8, fh - 8, 2, rim_dd)
    # The dark slot the stick runs in.
    ui.rect(im, SLOT_X, fy + 4, 5, fh - 8, ui.INK)
    ui.vline(im, SLOT_X + 4, fy + 5, fh - 10, (40, 26, 58, 255))
    # Pivot cap.
    cx, cy = PIVOT
    for y in range(int(cy) - 2, int(cy) + 3):
        for x in range(int(cx) - 2, int(cx) + 3):
            if math.hypot(x - cx + 0.5, y - cy + 0.5) <= 2.4:
                ui.px(im, x, y, METAL_D)
    ui.px(im, int(cx) - 1, int(cy) - 1, METAL)
    if cold:
        # Frost the brass: a desaturated, darker look when no Refresh is left.
        px = im.load()
        for y in range(H):
            for x in range(W):
                r, g, b, a = px[x, y]
                if a:
                    m = (r + g + b) // 3
                    px[x, y] = ((r + m) // 3, (g + m) // 3, (b + m) // 3 + 18, a)
    return im


def disc(im, cx, cy, r, ramp):
    hi, base, dark, darker = ramp
    for y in range(int(cy - r - 2), int(cy + r + 3)):
        for x in range(int(cx - r - 2), int(cx + r + 3)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d <= r + 1.0:
                ui.px(im, x, y, ui.INK)
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > r:
                continue
            c = base
            if dx + dy > r * 0.6:
                c = dark
            if dx + dy > r * 1.1:
                c = darker
            if math.hypot(dx + r * 0.38, dy + r * 0.38) < r * 0.34:
                c = hi
            ui.px(im, x, y, c)


def stick(i):
    im = ui.img(W, H)
    cx, cy = PIVOT
    ky, kr = KNOB_Y[i], KNOB_R[i]
    # The rod: two pixels wide with a lit edge, from the pivot to the knob.
    steps = int(abs(ky - cy)) + 1
    for s in range(steps):
        y = int(round(cy + (ky - cy) * s / max(1, steps - 1)))
        ui.px(im, int(cx) - 2, y, ui.INK)
        ui.px(im, int(cx) - 1, y, METAL_L)
        ui.px(im, int(cx), y, METAL)
        ui.px(im, int(cx) + 1, y, ui.INK)
    disc(im, cx, ky, kr, KNOB)
    return im


def main():
    frames = [housing(ui.SUN, ui.SUN_L, ui.SUN_D, ui.SUN_DD)]
    frames += [stick(i) for i in range(5)]
    frames.append(housing(ui.PINK, ui.PINK_L, ui.PINK_D, ui.PINK_DD))
    frames.append(housing(ui.SUN, ui.SUN_L, ui.SUN_D, ui.SUN_DD, cold=True))
    sheet = ui.img(W * FRAMES, H)
    for i, f in enumerate(frames):
        sheet.paste(f, (i * W, 0))
    ui.save("lever", sheet)
    if len(sys.argv) > 1:
        # Contact sheet: every stick position over the housing, at 4x.
        demo = ui.img(W * 5, H)
        for i in range(5):
            demo.alpha_composite(frames[0], (i * W, 0))
            demo.alpha_composite(frames[1 + i], (i * W, 0))
        demo.resize((demo.width * 4, demo.height * 4), Image.NEAREST).save(sys.argv[1])
    print("wrote lever.png")


if __name__ == "__main__":
    main()
