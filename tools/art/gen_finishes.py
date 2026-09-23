"""Generate BLOCKMANIA's animated pixel-art block finishes, material faces and stamp badges.

Run:  python tools/art/gen_finishes.py
Out:  assets/ui/finish_<id>.png   sprite sheets: columns = animation frames, rows = six block
                                  colors (x variants). Each cell is 24x24 art px (a 22x22 face
                                  plus a 1 px transparent gutter) exported at 4x nearest.
      assets/ui/stamp_<id>.png    12x12 badges, a horizontal strip of animation frames (14 px cells).
      assets/ui/block_glow.png    stepped pixel halo drawn under glowing finishes.
      assets/ui/finishes.json     frames / variants per sheet (the game reads it to slice sheets).

Everything is authored here as code: no external art, no image generators. Light comes from
the top-left, outlines are ink, and every finish keeps its block color readable while its
silhouette, surface marks and value pattern identify the material (never color alone).
Frame 0 of every animation is a calm "rest" pose: Reduced Motion shows only that frame.
"""
import colorsys
import json
import math
import os

from PIL import Image

import gen_ui as kit

N = 22            # face size in art px
CELL = N + 2      # face + 1 px gutter on each side (keeps neighbours from bleeding)
S_N = 12          # stamp badge size
S_CELL = S_N + 2
COLORS = ("red", "orange", "yellow", "green", "blue", "purple")
INK = kit.INK
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)
META = {}


# ---------------------------------------------------------------- color helpers
def rgba(c, a=255):
    return (int(c[0]), int(c[1]), int(c[2]), int(a))


def mixc(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(a[i] * (1 - t) + b[i] * t) for i in range(3)) + (255,)


def with_alpha(c, a):
    return c[:3] + (int(max(0, min(255, a))),)


def hsv(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, s, v)
    return (round(r * 255), round(g * 255), round(b * 255), 255)


def ramp(color):
    """(hi, light, base, dark, darker) from the kit's block palette."""
    return kit.BLOCKS[color]


def over(dst, src):
    """Alpha-composite one RGBA pixel onto another."""
    sa = src[3] / 255.0
    if sa <= 0:
        return dst
    da = dst[3] / 255.0
    oa = sa + da * (1 - sa)
    if oa <= 0:
        return CLEAR
    return tuple(round((src[i] * sa + dst[i] * da * (1 - sa)) / oa) for i in range(3)) + (round(oa * 255),)


BAYER4 = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))


def dither(x, y, t):
    """Ordered 4x4 dither: True when a pixel should take the 'upper' color at mix t (0..1)."""
    return t * 16.0 > BAYER4[y % 4][x % 4] + 0.5


def hash01(*v):
    h = 2166136261
    for n in v:
        h = ((h ^ (int(n) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    h ^= h >> 13
    h = (h * 1274126177) & 0xFFFFFFFF
    return (h & 0xFFFFFF) / float(0x1000000)


def vnoise(x, y, seed):
    """Smooth value noise, period-free, deterministic."""
    x0, y0 = math.floor(x), math.floor(y)
    fx, fy = x - x0, y - y0
    sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = hash01(x0, y0, seed)
    b = hash01(x0 + 1, y0, seed)
    c = hash01(x0, y0 + 1, seed)
    d = hash01(x0 + 1, y0 + 1, seed)
    return (a * (1 - sx) + b * sx) * (1 - sy) + (c * (1 - sx) + d * sx) * sy


def fbm(x, y, seed, octaves=3):
    v, amp, tot = 0.0, 1.0, 0.0
    for o in range(octaves):
        v += vnoise(x * (2 ** o), y * (2 ** o), seed + o * 31) * amp
        tot += amp
        amp *= 0.5
    return v / tot


# ---------------------------------------------------------------- canvas
class Face:
    """A 22x22 face with the chamfered block silhouette."""

    def __init__(self, cut=3):
        self.im = Image.new("RGBA", (N, N), CLEAR)
        self.inside = kit.chamfer_mask(N, N, cut)
        self.cut = cut

    def get(self, x, y):
        return self.im.getpixel((x, y))

    def set(self, x, y, c):
        if 0 <= x < N and 0 <= y < N and self.inside(x, y):
            self.im.putpixel((x, y), c)

    def blend(self, x, y, c):
        if 0 <= x < N and 0 <= y < N and self.inside(x, y):
            self.im.putpixel((x, y), over(self.get(x, y), c))

    def edge(self, x, y):
        """Distance in px from the silhouette border (0 = outline pixel)."""
        d = 0
        while d < N and all(self.inside(x + dx, y + dy) for dx in range(-d - 1, d + 2) for dy in range(-d - 1, d + 2)
                            if abs(dx) + abs(dy) <= d + 1):
            d += 1
        return d

    def fill(self, fn):
        """fn(x, y) -> color for every pixel inside the silhouette."""
        for y in range(N):
            for x in range(N):
                if self.inside(x, y):
                    c = fn(x, y)
                    if c is not None:
                        self.im.putpixel((x, y), c)

    def outline(self, c=INK):
        for y in range(N):
            for x in range(N):
                if self.inside(x, y) and not all(self.inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    self.im.putpixel((x, y), c)

    def bevel(self, light, dark, depth=1, light2=None, dark2=None):
        """Top/left light, bottom/right dark rim just inside the outline."""
        for y in range(N):
            for x in range(N):
                if not self.inside(x, y):
                    continue
                d = EDGE[y][x]
                if d < 1 or d > depth:
                    continue
                top_left = (x + y) < (N - 1)
                if d == 1:
                    self.im.putpixel((x, y), light if top_left else dark)
                elif d == 2:
                    self.im.putpixel((x, y), (light2 or light) if top_left else (dark2 or dark))


def _edge_table():
    inside = kit.chamfer_mask(N, N, 3)
    table = [[-1] * N for _ in range(N)]
    for y in range(N):
        for x in range(N):
            if not inside(x, y):
                continue
            d = 0
            while True:
                ring = [(x + dx, y + dy) for dx in range(-(d + 1), d + 2) for dy in range(-(d + 1), d + 2)
                        if abs(dx) + abs(dy) <= d + 1 and max(abs(dx), abs(dy)) <= d + 1]
                if all(inside(px, py) for px, py in ring):
                    d += 1
                    if d > N:
                        break
                else:
                    break
            table[y][x] = d
    return table


EDGE = _edge_table()   # EDGE[y][x]: 0 = outline ring, 1 = first rim, ... (chamfer 3)


def star(face, x, y, size, core=WHITE, arm=None):
    """Four-point pixel sparkle. size 0 = single px, 1 = plus, 2 = long plus with soft arms."""
    arm = arm or with_alpha(WHITE, 170)
    if size <= 0:
        face.blend(x, y, with_alpha(core, 200))
        return
    face.set(x, y, core)
    for k in range(1, size + 1):
        a = core if k < size else arm
        for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
            face.blend(x + dx, y + dy, a)
    if size >= 2:
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            face.blend(x + dx, y + dy, with_alpha(core, 90))


def sweep_amount(x, y, frame, start, length, width=2.2, slope=1.0):
    """Brightness (0..1) of a diagonal light band that crosses the face during
    frames [start, start + length)."""
    if frame < start or frame >= start + length:
        return 0.0
    k = (frame - start + 0.5) / length
    center = -6 + k * (N * 2 + 12)
    d = abs((x + y * slope) - center)
    return max(0.0, 1.0 - d / width)


# ---------------------------------------------------------------- finishes
# Each finish: frames, fps, variants, draw(color, frame, variant) -> Face

def f_glass(color, frame, variant):
    """Stained glass: thin lead came splits the face into jewel panes that flare as light sweeps."""
    hi, light, base, dark, darker = ramp(color)
    lead = (34, 27, 48, 255)
    lead_hi = (110, 98, 138, 255)
    f = Face()

    def pane(cx, cy):
        if abs(cx) + abs(cy) <= 6.5:
            return "c"
        return ("t" if cy < 0 else "b") + ("l" if cx < 0 else "r")

    def px(x, y):
        d = EDGE[y][x]
        cx, cy = x - 10.5, y - 10.5
        if d == 1:
            return lead_hi if (x + y) < N - 1 else lead
        if abs(abs(cx) + abs(cy) - 7.0) < 0.55:
            return lead
        p = pane(cx, cy)
        if p == "c":
            r = abs(cx) + abs(cy)
            c = mixc(hi, light, r / 6.5)
        elif p == "tl":
            c = mixc(light, base, (x + y) / 16.0)
        elif p == "br":
            c = mixc(base, dark, (x + y - 22) / 14.0)
        else:
            c = mixc(base, light if p == "tr" else dark, 0.25)
        if hash01(x, y, 7 + variant) > 0.95:
            c = mixc(c, WHITE, 0.4)
        s = sweep_amount(x, y, frame, 7, 7, 3.0)
        a = 236
        if s > 0:
            c = mixc(c, WHITE, 0.7 * s)
            a = 236 + round(19 * s)
        return with_alpha(c, a)

    f.fill(px)
    f.outline(INK)
    # a bright streak at the top-left of each pane sells the glass
    for x, y in ((4, 3), (5, 3), (3, 4), (3, 5), (10, 6), (9, 7), (16, 4), (17, 4), (4, 15), (4, 16), (15, 15)):
        f.blend(x, y, with_alpha(WHITE, 200 if y < 9 else 120))
    return f


def f_crystal(color, frame, variant):
    """Step-cut gem: concentric facet steps lit from the top-left, twinkling sparkles."""
    hi, light, base, dark, darker = ramp(color)
    f = Face()
    side_tone = {  # step parity -> (top, left, right, bottom)
        0: (mixc(hi, WHITE, 0.3), hi, base, dark),
        1: (light, mixc(light, hi, 0.5), dark, darker),
    }

    def px(x, y):
        d = EDGE[y][x]
        cx, cy = x - 10.5, y - 10.5
        if d >= 7:
            t = (cx + cy + 8) / 16.0
            c = mixc(light, base, t)
            if abs(cx - cy) < 1.0 and cx + cy < 0:
                c = mixc(c, WHITE, 0.5)
            return c
        step = {1: 0, 2: 1, 3: 1, 4: 0, 5: 0, 6: 1}.get(d, 0)
        top, left, right, bottom = side_tone[step]
        if abs(cy) >= abs(cx):
            return top if cy < 0 else bottom
        return left if cx < 0 else right

    f.fill(px)
    f.outline(INK)
    f.set(8, 8, WHITE)
    f.set(9, 8, with_alpha(WHITE, 200))
    seq = [0, 1, 2, 1, 0]
    points = [((4, 5), 1), ((16, 8), 6), ((9, 16), 11)]
    for (sx, sy), start in points:
        k = frame - start
        if 0 <= k < len(seq):
            star(f, sx, sy, seq[k])
    return f


def f_neon(color, frame, variant):
    """Neon tube bent into a square on a black glass sign; the tube flickers now and then."""
    hi, light, base, dark, darker = ramp(color)
    panel = (22, 17, 36, 255)
    dim = frame in (17, 19)
    half = frame == 18
    tube_edge = mixc(base, darker, 0.55) if dim else (mixc(base, dark, 0.3) if half else base)
    tube_core = mixc(light, dark, 0.45) if dim else (mixc(hi, light, 0.6) if half else mixc(hi, WHITE, 0.55))
    spill = mixc(panel, base, 0.18 if dim else 0.36)
    f = Face()

    def px(x, y):
        d = EDGE[y][x]
        if d == 1:
            return (58, 48, 82, 255) if (x + y) < N - 1 else (10, 8, 18, 255)
        return panel

    f.fill(px)
    # glow spill on the backing, then the tube (edge / core / edge)
    kit.outline_shape(f.im, 3, 3, 16, 16, 3, spill)
    kit.outline_shape(f.im, 7, 7, 8, 8, 2, spill)
    kit.outline_shape(f.im, 4, 4, 14, 14, 3, tube_edge)
    kit.outline_shape(f.im, 5, 5, 12, 12, 2, tube_core)
    kit.outline_shape(f.im, 6, 6, 10, 10, 2, tube_edge)
    # electrode gap with two metal caps at the bottom
    for x in (10, 11):
        for y in (15, 16, 17):
            f.set(x, y, spill if y != 17 else panel)
    for x in (9, 12):
        for y in (15, 16, 17):
            f.set(x, y, (150, 146, 170, 255) if y == 16 else (96, 92, 118, 255))
    # mounting screws and a glass reflection
    for x, y in ((3, 3), (18, 3), (3, 18), (18, 18)):
        f.set(x, y, (84, 76, 108, 255))
    f.set(8, 9, with_alpha(WHITE, 60))
    f.set(9, 8, with_alpha(WHITE, 60))
    f.outline(INK)
    return f


GOLD = ((255, 250, 205, 255), (255, 224, 112, 255), (238, 176, 48, 255), (186, 114, 26, 255), (118, 66, 18, 255))


def f_gold(color, frame, variant):
    """Gilded bullion with an engraved groove and an enamel cabochon; a shine rolls across."""
    hi, light, base, dark, darker = ramp(color)
    g_hi, g_l, g, g_d, g_dd = GOLD
    f = Face()

    def px(x, y):
        d = EDGE[y][x]
        tl = (x + y) < N - 1
        if d == 1:
            c = g_hi if tl else g_dd
        elif d == 2:
            c = g_l if tl else g_d
        else:
            t = y / N
            c = mixc(g_l, g, min(1.0, t * 1.4))
            if d == 3 and not tl:
                c = mixc(c, g_d, 0.4)
        # engraved groove
        if d == 4:
            c = g_d if tl else g_hi
        cx, cy = x - 10.5, y - 10.5
        r = math.hypot(cx, cy)
        if r <= 5.2:
            if r > 4.2:
                c = g_dd if cx + cy > -1 else g_hi   # bezel
            else:
                lit = (-(cx + cy) / 5.6 + 1.0) / 2.0
                c = mixc(dark, light, lit)
                if r > 3.3 and cx + cy > 0:
                    c = mixc(c, darker, 0.5)
        s = sweep_amount(x, y, frame, 5, 6, 2.4)
        if s > 0 and r > 4.2:
            c = mixc(c, WHITE, 0.8 * s)
        elif s > 0:
            c = mixc(c, hi, 0.5 * s)
        return c

    f.fill(px)
    f.outline(INK)
    # cabochon highlight and gold studs
    f.set(9, 8, hi)
    f.set(8, 9, hi)
    f.set(9, 9, WHITE)
    for x, y in ((6, 6), (15, 6), (6, 15), (15, 15)):
        f.set(x, y, g_hi)
        f.set(x + 1, y + 1, g_dd)
    if 10 <= frame <= 13:
        star(f, 16, 5, [1, 2, 1, 0][frame - 10])
    return f


def f_marble(color, frame, variant):
    """Polished marble: soft clouds, one continuous vein in the block color, a slow gloss sweep."""
    hi, light, base, dark, darker = ramp(color)
    stone = mixc((248, 244, 236, 255), hi, 0.12)
    cloud = mixc((232, 226, 218, 255), light, 0.16)
    seed = 40 + variant * 17
    f = Face()

    def px(x, y):
        d = EDGE[y][x]
        tl = (x + y) < N - 1
        if d == 1:
            return WHITE if tl else mixc(cloud, dark, 0.3)
        n = fbm(x / 6.0, y / 6.0, seed)
        c = cloud if n > 0.55 else stone
        s = sweep_amount(x, y, frame, 8, 9, 3.4)
        if s > 0:
            c = mixc(c, WHITE, 0.6 * s)
        return c

    f.fill(px)

    def walk(y0, slope, amp, sd):
        pts = []
        for x in range(2, 20):
            y = y0 + slope * (x - 2) + (fbm(x / 4.0, 0.5, sd) - 0.5) * amp
            pts.append((x, int(round(y))))
        line = []
        for (x0, ya), (x1, yb) in zip(pts, pts[1:]):
            line.append((x0, ya))
            step = 1 if yb > ya else -1
            for yy in range(ya + step, yb, step):
                line.append((x0 if abs(yy - ya) < abs(yy - yb) else x1, yy))
        line.append(pts[-1])
        return line

    def ok(x, y):
        return 0 <= y < N and 0 <= x < N and EDGE[y][x] >= 2

    starts = [(15, -0.55), (5, 0.5), (17, -0.8)]
    y0, slope = starts[variant % 3]
    for x, y in walk(y0, slope, 7, seed + 3):
        if ok(x, y):
            f.set(x, y, dark)
            if ok(x, y - 1) and f.get(x, y - 1) != dark:
                f.set(x, y - 1, light)
    branch = walk(y0 + (4 if slope < 0 else -4), -slope * 0.6, 5, seed + 8)
    for i, (x, y) in enumerate(branch):
        if 7 <= x <= 15 and ok(x, y) and f.get(x, y) != dark:
            f.set(x, y, mixc(light, base, 0.4) if i % 5 else light)
    f.outline(INK)
    for x, y in ((4, 3), (5, 3), (3, 4), (3, 5)):
        f.set(x, y, WHITE)
    return f


def f_cyberpunk(color, frame, variant):
    """Circuit board: a chip with a blinking LED, traces in the block color carrying data pulses."""
    hi, light, base, dark, darker = ramp(color)
    pcb = (40, 30, 74, 255)
    pcb_d = (30, 22, 58, 255)
    cyan = (93, 241, 247, 255)
    magenta = (245, 79, 183, 255)
    pin = (200, 196, 220, 255)
    f = Face()

    def px(x, y):
        d = EDGE[y][x]
        if d == 1:
            return (84, 70, 132, 255) if (x + y) < N - 1 else (16, 12, 32, 255)
        return pcb_d if (x + y) % 4 == 0 and d > 2 else pcb

    f.fill(px)
    traces = [
        [(9, 6), (9, 4), (4, 4)],
        [(15, 12), (17, 12), (17, 17)],
        [(12, 15), (12, 17), (6, 17)],
        [(6, 12), (3, 12)],
        [(15, 9), (18, 9), (18, 4)],
    ]
    paths = []
    for tr in traces:
        pts = []
        for (x0, y0), (x1, y1) in zip(tr, tr[1:]):
            steps = max(abs(x1 - x0), abs(y1 - y0))
            for i in range(steps):
                pts.append((x0 + (x1 - x0) * i // steps, y0 + (y1 - y0) * i // steps))
        pts.append(tr[-1])
        paths.append(pts)
        for x, y in pts:
            f.set(x, y, mixc(base, dark, 0.2))
        ex, ey = tr[-1]
        f.set(ex, ey, hi)
    # chip: black package with a bevel, silver pins and a lit die window in the block color
    kit.rect(f.im, 7, 7, 8, 8, (10, 8, 18, 255))
    kit.hline(f.im, 7, 7, 8, (70, 62, 104, 255))
    kit.vline(f.im, 7, 8, 7, (46, 40, 72, 255))
    for i in (9, 12):
        f.set(i, 6, pin)
        f.set(i, 15, pin)
        f.set(6, i, pin)
        f.set(15, i, pin)
    lit = (frame // 3) % 2 == 0
    kit.rect(f.im, 9, 9, 4, 4, dark)
    kit.rect(f.im, 10, 10, 2, 2, (hi if lit else light))
    f.set(9, 9, light)
    f.set(8, 8, (120, 110, 150, 255))   # pin-1 dot
    for x, y in ((2, 3), (2, 4), (3, 2), (4, 2)):
        f.set(x, y, cyan)
    for x, y in ((19, 18), (19, 17), (18, 19), (17, 19)):
        f.set(x, y, magenta)
    for i, pts in enumerate(paths):
        n = len(pts)
        pos = (frame / 12.0 * (n + 3) + i * 2) % (n + 3) - 1
        for k, (x, y) in enumerate(pts[:-1]):
            dd = pos - k
            if 0 <= dd < 1:
                f.set(x, y, WHITE)
            elif 1 <= dd < 2:
                f.set(x, y, hi)
    f.outline(INK)
    return f


WOOD = ((244, 206, 148, 255), (218, 166, 102, 255), (186, 130, 74, 255), (142, 92, 52, 255), (98, 60, 38, 255))


def f_wood(color, frame, variant):
    """Painted toy block: bare maple bevels, a worn painted face, a carved ring."""
    hi, light, base, dark, darker = ramp(color)
    w_hi, w_l, w, w_d, w_dd = WOOD
    seed = 70 + variant * 13
    f = Face()

    def grain(x, y):
        return math.sin(y * 1.15 + fbm(x / 6.0, y / 3.0, seed) * 7.0 + variant * 2.0)

    def px(x, y):
        d = EDGE[y][x]
        tl = (x + y) < N - 1
        if d <= 3:
            c = (w_l if d == 1 else w) if tl else (w_d if d == 1 else mixc(w, w_d, 0.5))
            if grain(x, y) > 0.75:
                c = mixc(c, w_dd, 0.35)
            return c
        if d == 4:
            return w_dd if tl else w_hi       # carved groove around the paint
        t = (x + y) / (2.0 * N)
        c = mixc(light, base, min(1.0, t * 1.6))
        if grain(x, y) > 0.8:
            c = mixc(c, dark, 0.28)
        # worn paint shows wood at a few corners
        if hash01(x, y, seed) > 0.965 and d == 5:
            c = w_l
        cx, cy = x - 10.5, y - 10.5
        r = math.hypot(cx, cy)
        if 2.6 < r <= 3.8:
            c = darker if cx + cy < 0 else hi
        return c

    f.fill(px)
    f.outline(INK)
    kit.hline(f.im, 6, 5, 3, mixc(hi, WHITE, 0.4))
    return f


def f_candy(color, frame, variant):
    """Glossy pinwheel candy whose swirl slowly turns."""
    hi, light, base, dark, darker = ramp(color)
    cream = mixc(hi, WHITE, 0.6)
    f = Face()
    turn = frame / 12.0

    def px(x, y):
        d = EDGE[y][x]
        tl = (x + y) < N - 1
        if d == 1:
            return light if tl else dark
        if d == 2:
            return mixc(hi, light, 0.4) if tl else mixc(base, dark, 0.5)
        cx, cy = x - 10.5, y - 10.5
        r = math.hypot(cx, cy)
        a = math.atan2(cy, cx) / (2 * math.pi)
        s = (a * 3 + r * 0.075 - turn) % 1.0
        c = base if s < 0.5 else cream
        # rounded shading: lighter towards the top-left
        shade = (cx + cy) / 20.0
        if shade > 0.3:
            c = mixc(c, dark, (shade - 0.3) * 0.8)
        elif shade < -0.4:
            c = mixc(c, WHITE, (-shade - 0.4) * 0.6)
        if r < 1.2:
            c = light
        return c

    f.fill(px)
    f.outline(INK)
    for x, y in ((4, 4), (5, 4), (6, 4), (4, 5), (4, 6), (5, 5)):
        f.set(x, y, WHITE)
    f.set(16, 15, with_alpha(WHITE, 200))
    f.set(15, 17, with_alpha(WHITE, 140))
    return f


def voronoi_cracks(seed, count=7):
    pts = [(1 + hash01(i, seed) * 20, 1 + hash01(i, seed + 1) * 20) for i in range(count)]

    def nearest(x, y):
        return min(range(count), key=lambda i: math.hypot(x - pts[i][0], y - pts[i][1]))

    owner = {(x, y): nearest(x, y) for y in range(-1, N + 1) for x in range(-1, N + 1)}
    crack = {}
    for y in range(N):
        for x in range(N):
            me = owner[(x, y)]
            line = owner[(x + 1, y)] != me or owner[(x, y + 1)] != me
            near = any(owner[(x + dx, y + dy)] != me for dx in (-1, 0, 1) for dy in (-1, 0, 1))
            crack[(x, y)] = (0 if line else (1 if near else 2), me, pts[me])
    return crack


_CRACKS = {}


def f_lava(color, frame, variant):
    """Cooled basalt plates over magma in the block color; heat waves pulse along the cracks."""
    hi, light, base, dark, darker = ramp(color)
    if variant not in _CRACKS:
        _CRACKS[variant] = voronoi_cracks(101 + variant * 7)
    cracks = _CRACKS[variant]
    magma = [dark, base, light, hi, (255, 250, 226, 255)]
    f = Face()
    t = frame / 16.0

    def px(x, y):
        d = EDGE[y][x]
        tl = (x + y) < N - 1
        if d == 1:
            return (84, 64, 70, 255) if tl else (18, 12, 20, 255)
        kind, cell, (sx, sy) = cracks[(x, y)]
        heat = 0.5 + 0.5 * math.sin(2 * math.pi * (t - (x * 0.05 + y * 0.035)))
        if kind == 0:
            return magma[max(0, min(4, int(1.0 + heat * 3.6)))]
        shade = 0.2 + 0.55 * hash01(cell, variant, 9)
        c = mixc((34, 25, 33, 255), (72, 56, 62, 255), shade)
        if (x - sx) + (y - sy) < -3.0:
            c = mixc(c, (116, 94, 98, 255), 0.4)
        if kind == 1:
            c = mixc(c, base, 0.25 + 0.3 * heat)
        return c

    f.fill(px)
    f.outline(INK)
    return f


def f_ice(color, frame, variant):
    """Clear ice cube: frosted rim, a deeper core, trapped bubbles and a crack; cold glints."""
    hi, light, base, dark, darker = ramp(color)
    frost = mixc(hi, (240, 252, 255, 255), 0.65)
    pale = mixc(light, (190, 234, 255, 255), 0.45)
    deep = mixc(base, (84, 150, 214, 255), 0.3)
    f = Face()

    def px(x, y):
        d = EDGE[y][x]
        tl = (x + y) < N - 1
        if d == 1:
            return WHITE if tl else mixc(deep, darker, 0.45)
        if 5 <= x <= 16 and 5 <= y <= 16:
            c = mixc(deep, pale, 0.2 + 0.4 * (1 - (x + y - 10) / 22.0))
            if x == 5 or y == 5:
                c = mixc(pale, WHITE, 0.55)
            elif x == 16 or y == 16:
                c = mixc(deep, darker, 0.35)
            return with_alpha(c, 234)
        c = pale if tl else mixc(pale, deep, 0.45)
        if d == 2 and y < 7:
            c = frost
        return with_alpha(c, 242)

    f.fill(px)
    for x, y in ((6, 3), (7, 4), (11, 3), (15, 3), (15, 4), (3, 8)):
        f.set(x, y, frost)
    for bx, by in ((8, 12), (13, 8), (11, 14)):
        f.set(bx, by, with_alpha(WHITE, 220))
    f.blend(12, 13, with_alpha(WHITE, 120))
    for x, y in ((6, 15), (7, 14), (8, 13), (9, 13), (10, 12), (10, 11), (11, 10)):
        f.blend(x, y, with_alpha(WHITE, 190))
    f.outline(INK)
    seq = [0, 1, 2, 1, 0]
    if 3 <= frame < 8:
        star(f, 5, 5, seq[frame - 3])
    if 10 <= frame < 13:
        star(f, 16, 13, [0, 1, 0][frame - 10])
    return f


CHROME = ((252, 253, 255, 255), (214, 224, 238, 255), (152, 166, 188, 255), (82, 94, 118, 255), (38, 44, 62, 255))


def f_chrome(color, frame, variant):
    """Mirror chrome: sky above a sharp horizon reflecting the block color; a glint races by."""
    hi, light, base, dark, darker = ramp(color)
    c_w, c_l, c_m, c_d, c_dd = CHROME
    f = Face()

    def px(x, y):
        d = EDGE[y][x]
        tl = (x + y) < N - 1
        if d == 1:
            return c_w if tl else c_dd
        cx = (x - 10.5) / 9.5
        horizon = 10 + round(cx * cx * 1.6)
        if y < horizon:
            c = mixc(c_w, c_l, (y - 2) / max(1, horizon - 2))
            c = mixc(c, hi, 0.3)
        elif y == horizon:
            c = c_dd
        elif y <= horizon + 3:
            c = mixc(dark, base, (y - horizon - 1) / 3.0)
        else:
            c = mixc(light, mixc(c_l, hi, 0.4), (y - horizon - 4) / 5.0)
        # cylindrical falloff at the sides
        edge = abs(cx)
        if edge > 0.72:
            c = mixc(c, c_d, (edge - 0.72) * 1.6)
        s = sweep_amount(x, y, frame, 6, 6, 1.6, slope=0.6)
        if s > 0:
            c = mixc(c, WHITE, 0.9 * s)
        return c

    f.fill(px)
    f.outline(INK)
    for y in (4, 5, 6):
        f.set(5, y, WHITE)
    f.set(6, 4, WHITE)
    if 11 <= frame <= 14:
        star(f, 16, 4, [1, 2, 1, 0][frame - 11])
    return f


def f_aurora(color, frame, variant):
    """A night sky over tiny mountains; aurora curtains in mint, the block color and violet ripple."""
    hi, light, base, dark, darker = ramp(color)
    mint = (140, 255, 214, 255)
    violet = (196, 146, 255, 255)
    sky_top = (10, 14, 38, 255)
    sky_low = mixc((26, 22, 60, 255), darker, 0.55)
    t = frame / 16.0
    ridge = [15, 14, 14, 13, 14, 15, 15, 14, 13, 12, 12, 13, 14, 15, 14, 13, 14, 15, 16, 15, 15, 16]
    f = Face()

    def px(x, y):
        d = EDGE[y][x]
        tl = (x + y) < N - 1
        if d == 1:
            return mixc(sky_low, light, 0.4) if tl else (6, 6, 16, 255)
        if y >= ridge[x] + 3:
            return (16, 12, 30, 255) if y > ridge[x] + 3 else mixc((16, 12, 30, 255), hi, 0.45)
        c = mixc(sky_top, sky_low, y / 16.0)
        low = 11.0 + 1.6 * math.sin(x * 0.5 + 2 * math.pi * t) + 0.9 * math.sin(x * 1.1 - 4 * math.pi * t)
        rise = low - y
        ray = 0.5 + 0.5 * math.sin(x * 1.9 + 2 * math.pi * t)
        height = 4 + 4 * ray
        if 0 <= rise < height:
            k = rise / height
            if k < 0.18:
                c = mint
            elif k < 0.5:
                c = mixc(mint, light, (k - 0.18) / 0.32)
            elif k < 0.8:
                c = mixc(c, base, 0.75)
            else:
                c = mixc(c, violet, 0.45)
        elif hash01(x, y, 5) > 0.94 and y < 8:
            c = mixc(c, WHITE, 0.7)
        return c

    f.fill(px)
    f.outline(INK)
    return f


def f_starfall(color, frame, variant):
    """Deep space with a nebula in the block color, twinkling stars and a shooting star."""
    hi, light, base, dark, darker = ramp(color)
    space = (13, 11, 34, 255)
    f = Face()
    seed = 200 + variant
    cx, cy = (14, 8) if variant == 0 else (8, 14)

    def px(x, y):
        d = EDGE[y][x]
        tl = (x + y) < N - 1
        if d == 1:
            return (58, 56, 108, 255) if tl else (6, 6, 18, 255)
        n = fbm(x / 5.0, y / 5.0, seed)
        k = n * 1.1 + 0.62 - math.hypot(x - cx, y - cy) / 10.0
        if k > 0.95:
            return mixc(light, hi, 0.4)
        if k > 0.84:
            return mixc(base, light, 0.4)
        if k > 0.74:
            return mixc(dark, base, 0.5) if dither(x, y, 0.7) else mixc(base, light, 0.2)
        if k > 0.64:
            return mixc(darker, dark, 0.6)
        if k > 0.55:
            return mixc(space, darker, 0.8) if dither(x, y, 0.55) else mixc(space, darker, 0.3)
        return space

    f.fill(px)
    stars = [(5, 5, 0), (15, 3, 3), (18, 11, 7), (6, 12, 10), (12, 18, 5), (4, 17, 12), (18, 17, 15)]
    for sx, sy, ph in stars:
        b = 0.5 + 0.5 * math.cos(2 * math.pi * (frame + ph) / 24.0)
        f.set(sx, sy, mixc(light, WHITE, b) if b > 0.35 else mixc(dark, light, 0.6))
    star(f, cx - 3 if variant == 0 else cx + 3, cy + 1, 1, WHITE, with_alpha(hi, 200))
    if 2 <= frame <= 7:
        k = frame - 2
        hx, hy = 17 - k * 3, 3 + k * 2
        f.set(hx, hy, WHITE)
        for j in range(1, 5):
            f.blend(hx + int(j * 1.5), hy - j, with_alpha(mixc(hi, light, j / 4.0), 220 - j * 45))
    f.outline(INK)
    return f


def f_prism(color, frame, variant):
    """Holographic foil: rainbow bands flow over the block color around an etched diamond."""
    hi, light, base, dark, darker = ramp(color)
    t = frame / 12.0
    f = Face()

    def px(x, y):
        d = EDGE[y][x]
        tl = (x + y) < N - 1
        rainbow = hsv((x - y) * 0.035 + (x + y) * 0.012 - t, 0.42, 1.0)
        if d == 1:
            return mixc(WHITE, rainbow, 0.35) if tl else mixc(CHROME[3], rainbow, 0.25)
        if d == 2:
            return mixc(CHROME[1], rainbow, 0.5) if tl else mixc(CHROME[2], rainbow, 0.4)
        cx, cy = x - 10.5, y - 10.5
        diamond = abs(cx) + abs(cy)
        body = mixc(light, base, min(1.0, (x + y) / 30.0))
        if diamond <= 5.0:
            c = mixc(hi, rainbow, 0.55)
            if cx + cy > 1.5:
                c = mixc(c, base, 0.35)
        elif diamond <= 6.0:
            c = darker if cx + cy > 0 else WHITE
        else:
            band = (x - y + frame * 2) % 7
            c = mixc(body, rainbow, 0.42 if band < 3 else 0.2)
        return c

    f.fill(px)
    f.outline(INK)
    for x, y in ((4, 4), (5, 4), (4, 5)):
        f.set(x, y, WHITE)
    if 7 <= frame <= 10:
        star(f, 10, 7, [1, 2, 1, 0][frame - 7])
    return f


# id: (draw, frames, fps, variants)
FINISHES = {
    "glass": (f_glass, 16, 9, 1),
    "crystal": (f_crystal, 16, 9, 1),
    "neon": (f_neon, 24, 10, 1),
    "gold": (f_gold, 16, 9, 1),
    "marble": (f_marble, 20, 8, 3),
    "cyberpunk": (f_cyberpunk, 12, 8, 1),
    "wood": (f_wood, 1, 1, 2),
    "candy": (f_candy, 12, 6, 1),
    "lava": (f_lava, 16, 7, 2),
    "ice": (f_ice, 16, 8, 1),
    "chrome": (f_chrome, 16, 10, 1),
    "aurora": (f_aurora, 16, 6, 1),
    "starfall": (f_starfall, 24, 8, 2),
    "prism": (f_prism, 12, 7, 1),
}


# ---------------------------------------------------------------- stamps (12x12)
def badge_mask(kind):
    """Silhouette predicate for each stamp shape (distinct shapes, not just colors)."""
    c = (S_N - 1) / 2.0
    if kind == "star":
        pts = []
        for i in range(10):
            ang = -math.pi / 2 + i * math.pi / 5
            rad = 6.6 if i % 2 == 0 else 3.4
            pts.append((c + math.cos(ang) * rad, c + 0.6 + math.sin(ang) * rad))
        return lambda x, y: _in_poly(x, y, pts)
    if kind == "coin":
        return lambda x, y: math.hypot(x - c, y - c) <= 5.8
    if kind == "token":
        return lambda x, y: max(abs(x - c), abs(y - c)) <= 5.6 and abs(x - c) + abs(y - c) <= 8.2
    if kind == "gem":
        return lambda x, y: abs(x - c) * 0.9 + abs(y - c) <= 6.4
    raise ValueError(kind)


def _in_poly(x, y, pts):
    inside = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


GLYPHS = {
    "dot": ["##", "##"],
    "credit": [".##", "#..", "#..", "#..", ".##"],
    "bolt": ["..#", ".#.", "###", ".#.", "#.."],
    "back": [".#...", "####.", ".#..#", "....#", ".###."],
}


def stamp(kind, face_ramp, glyph, frame):
    hi, light, base, dark = face_ramp
    inside = badge_mask(kind)
    im = Image.new("RGBA", (S_N, S_N), CLEAR)
    c = (S_N - 1) / 2.0

    def ins(x, y):
        return 0 <= x < S_N and 0 <= y < S_N and inside(x, y)

    for y in range(S_N):
        for x in range(S_N):
            if not ins(x, y):
                continue
            border = not all(ins(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if border:
                col = INK
            else:
                rim = not all(ins(x + dx, y + dy) for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)))
                lit = (x - c) + (y - c)
                if rim:
                    col = hi if lit < 0 else dark
                else:
                    col = mixc(light, base, min(1.0, max(0.0, (lit + 6) / 12.0)))
            s = sweep_amount(x * 22 / S_N, y * 22 / S_N, frame, 1, 3, 3.0)
            if s > 0 and col != INK:
                col = mixc(col, WHITE, 0.75 * s)
            im.putpixel((x, y), col)
    rows = GLYPHS[glyph]
    gw, gh = len(rows[0]), len(rows)
    ox, oy = round(c - gw / 2.0 + 0.5), round(c - gh / 2.0 + 0.5) + (1 if kind == "star" else 0)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "#":
                im.putpixel((ox + x + 1, oy + y + 1), dark)   # engraved drop shadow
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "#":
                im.putpixel((ox + x, oy + y), WHITE)
    if frame == 4:
        im.putpixel((2, 2) if kind != "star" else (5, 1), WHITE)
    return im


STAMPS = {
    # id: (shape, (hi, light, base, dark), glyph)
    "encore": ("star", ((255, 214, 226, 255), kit.PINK_L, kit.PINK, kit.PINK_D), "dot"),
    "refund": ("token", ((214, 238, 255, 255), kit.SKY_L, kit.SKY, kit.SKY_DD), "back"),
    "tip": ("coin", ((255, 250, 205, 255), kit.SUN_L, kit.SUN, kit.SUN_DD), "credit"),
    "memory": ("gem", ((236, 220, 255, 255), (206, 170, 255, 255), kit.LILAC, (92, 56, 160, 255)), "bolt"),
}
STAMP_FRAMES = 8


# ---------------------------------------------------------------- glow halo
def glow_sprite():
    """Stepped pixel halo: rings of decreasing alpha around a 22 px block (7 px reach)."""
    reach = 7
    size = N + reach * 2
    im = Image.new("RGBA", (size, size), CLEAR)
    alphas = [150, 112, 80, 56, 34, 18, 8]
    for y in range(size):
        for x in range(size):
            dx = max(reach - x, 0, x - (reach + N - 1))
            dy = max(reach - y, 0, y - (reach + N - 1))
            d = dx + dy if dx and dy else max(dx, dy)
            d = int(round(math.hypot(dx, dy))) if dx and dy else d
            if d == 0:
                im.putpixel((x, y), (255, 255, 255, 170))
            elif d <= reach:
                a = alphas[d - 1]
                if d >= 5 and dither(x, y, 0.5):
                    a = alphas[d - 2] // 2
                im.putpixel((x, y), (255, 255, 255, a))
    return im


# ---------------------------------------------------------------- output
def build_sheet(finish):
    draw, frames, fps, variants = FINISHES[finish]
    sheet = Image.new("RGBA", (frames * CELL, len(COLORS) * variants * CELL), CLEAR)
    for ci, color in enumerate(COLORS):
        for v in range(variants):
            for fr in range(frames):
                face = draw(color, fr, v)
                sheet.alpha_composite(face.im, (fr * CELL + 1, (ci * variants + v) * CELL + 1))
    return sheet


def build_stamp(sid):
    kind, face_ramp, glyph = STAMPS[sid]
    strip = Image.new("RGBA", (STAMP_FRAMES * S_CELL, S_CELL), CLEAR)
    for fr in range(STAMP_FRAMES):
        strip.alpha_composite(stamp(kind, face_ramp, glyph, fr), (fr * S_CELL + 1, 1))
    return strip


def main():
    for finish, (draw, frames, fps, variants) in FINISHES.items():
        kit.save("finish_" + finish, build_sheet(finish))
        META[finish] = {"frames": frames, "fps": fps, "variants": variants}
    for sid in STAMPS:
        kit.save("stamp_" + sid, build_stamp(sid))
    kit.save("block_glow", glow_sprite())
    meta = {"cell": CELL * kit.SCALE, "face": N * kit.SCALE, "finishes": META,
            "stamp_cell": S_CELL * kit.SCALE, "stamp_face": S_N * kit.SCALE, "stamp_frames": STAMP_FRAMES,
            "glow_reach": 7 * kit.SCALE}
    with open(os.path.join(kit.OUT, "finishes.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(meta, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print("wrote %d finish sheets, %d stamp strips and the glow halo to %s" % (len(FINISHES), len(STAMPS), kit.OUT))


if __name__ == "__main__":
    main()
