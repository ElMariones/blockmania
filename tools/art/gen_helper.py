"""Generates POPS, BLOCKMANIA's tutorial helper (original pixel art, authored as code).

POPS is the arcade's old caretaker bot: a rainbow afro with an antenna bulb, big ears, a round
peach face with slanted oval eyes and rosy cheeks, a fluffy white beard, and a ruffled collar
with a polka-dot bow tie. Drawn procedurally on a 56x62 canvas with three-tone shading and the
same 1-pixel ink outline as the card portraits (gen_cards.py).

Run:  python tools/art/gen_helper.py [contact.png]
Out:  assets/ui/helper.png          8 frames of 56x62 art pixels in one row:
                                     0 idle, 1 blink, 2 talk (open), 3 talk (half),
                                     4 point, 5 point + talk, 6 happy, 7 happy + talk
      assets/ui/helper_pointer.png  4 frames of 16x16: a white glove pointing right, down,
                                     left, up (exact 90-degree rotations, no resampling)
Godot draws both at whole-number scales with nearest filtering (BMTutorial).
"""
import math
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "ui")
S = 56
H = 62
OY = 6 ## everything is drawn 6 px lower so the antenna fits above the afro
INK = (26, 16, 38, 255)

HAIR = {  # light, base, dark
    "orange": ((255, 196, 96, 255), (255, 146, 44, 255), (214, 92, 22, 255)),
    "red": ((255, 118, 112, 255), (236, 52, 52, 255), (176, 26, 40, 255)),
    "yellow": ((255, 248, 150, 255), (255, 214, 44, 255), (224, 158, 20, 255)),
    "green": ((178, 250, 122, 255), (92, 214, 72, 255), (40, 158, 54, 255)),
    "blue": ((126, 214, 255, 255), (44, 158, 240, 255), (22, 98, 198, 255)),
    "cyan": ((160, 252, 250, 255), (40, 218, 232, 255), (18, 156, 182, 255)),
}
SKIN = ((255, 228, 202, 255), (250, 202, 172, 255), (226, 158, 128, 255))
EAR_IN = (222, 142, 118, 255)
CHEEK = (255, 150, 150, 255)
BEARD = ((255, 252, 244, 255), (240, 230, 214, 255), (206, 192, 176, 255))
MOUTH = (96, 28, 44, 255)
TONGUE = (255, 118, 130, 255)
COLLAR = ((255, 255, 255, 255), (220, 216, 230, 255))
BOW = ((120, 170, 255, 255), (52, 92, 222, 255), (30, 52, 160, 255))
SUIT = {"teal": ((90, 214, 190, 255), (40, 176, 158, 255)), "yellow": ((255, 226, 110, 255), (255, 196, 40, 255)),
        "red": ((255, 110, 110, 255), (228, 48, 58, 255))}
GLOVE = ((255, 255, 255, 255), (214, 212, 230, 255))
BULB_ON = ((255, 250, 200, 255), (255, 214, 60, 255))
BULB_OFF = ((200, 170, 120, 255), (150, 110, 60, 255))
METAL = (150, 150, 176, 255)


class Canvas:
    def __init__(self, w, h, oy=0):
        self.w, self.h = w, h
        self.oy = oy
        self.px = {}

    def put(self, x, y, c):
        x, y = int(x), int(y) + self.oy
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c

    def disc(self, cx, cy, r, ramp, light=(-1, -1)):
        """Filled circle with a lit upper-left and a shaded lower-right rim."""
        lx, ly = light
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                dx, dy = x - cx, y - cy
                d = math.hypot(dx, dy)
                if d > r + 0.35:
                    continue
                c = ramp[1]
                facing = (dx * lx + dy * ly) / max(0.01, d)
                if d > r - 1.4 and facing < -0.2:
                    c = ramp[2]
                elif d < r - 0.8 and facing > 0.35 and d > r * 0.25:
                    c = ramp[0]
                self.put(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.05:
                    self.put(x, y, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c, width=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / max(1, n)
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            for oy in range(width):
                for ox in range(width):
                    self.put(round(x) + ox - width // 2, round(y) + oy - width // 2, c)

    def image(self, outline=True):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            img.putpixel((x, y), c)
        if outline:
            src = img.copy()
            for y in range(self.h):
                for x in range(self.w):
                    if src.getpixel((x, y))[3] > 0:
                        continue
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.w and 0 <= ny < self.h and src.getpixel((nx, ny))[3] > 0 and src.getpixel((nx, ny)) != INK:
                            img.putpixel((x, y), INK)
                            break
        return img


# Afro puffs: (x, y, radius, color). Left side warm, top red to yellow to green, right cool.
PUFFS = [
    (12, 24, 5.6, "yellow"), (14, 16, 6.4, "orange"), (21, 10, 7.0, "red"), (30, 9, 7.2, "yellow"),
    (39, 12, 6.8, "green"), (44, 20, 6.2, "green"), (45, 28, 5.4, "blue"), (44, 35, 4.4, "cyan"),
    (19, 17, 5.2, "red"), (28, 15, 5.6, "yellow"), (36, 17, 5.4, "green"), (41, 25, 5.0, "blue"),
]


def draw_pops(frame):
    c = Canvas(S, H, OY)
    talk = frame in (2, 3, 5, 7)
    point = frame in (4, 5)
    happy = frame in (6, 7)
    # Antenna: a little bot bulb on a spring, lit while POPS talks.
    c.line(30, 3, 31, -3, METAL)
    c.put(29, 0, METAL)
    c.put(32, -1, METAL)
    bulb = BULB_ON if (talk or happy) else BULB_OFF
    c.disc(31, -4.4, 1.9, (bulb[0], bulb[1], bulb[1]))
    for x, y, r, col in PUFFS:
        c.disc(x, y, r, HAIR[col])
    # Ears (big, a little uneven like the drawing), then the face over them.
    for side in (-1, 1):
        ex, ey = 28 + side * 15.5, 33 + (1.5 if side > 0 else 0)
        c.ellipse(ex, ey, 4.8, 6.6, SKIN[2])
        c.ellipse(ex + side * 0.8, ey - 0.3, 4.2, 6.0, SKIN[1])
        c.ellipse(ex + side * 0.6, ey + 0.2, 2.2, 4.0, EAR_IN)
        c.ellipse(ex - side * 0.4, ey, 1.2, 2.6, SKIN[1])
    c.disc(28, 30, 12.2, SKIN)
    # Front curls of the fringe over the forehead.
    for x, y, r, col in ((18, 20, 3.4, "red"), (23, 18.5, 3.6, "yellow"), (29, 18, 3.6, "yellow"), (35, 19.5, 3.4, "green"), (39.5, 23, 3.0, "blue")):
        c.disc(x, y, r, HAIR[col])
    # Eyes: slanted ovals; blink = a short line; happy = little arcs.
    for ex, ey in ((22.5, 28), (32, 29.5)):
        if frame == 1:
            c.rect(ex - 1, ey + 1, ex + 1, ey + 1, INK)
        elif happy:
            c.put(ex - 1, ey + 1, INK)
            c.put(ex, ey, INK)
            c.put(ex + 1, ey + 1, INK)
        else:
            c.rect(ex, ey - 2, ex + 1, ey + 2, INK)
            c.put(ex + 1, ey - 3, INK)
            c.put(ex, ey + 3, INK)
            c.put(ex + 1, ey - 1, (90, 80, 120, 255))
    c.rect(19, 33, 21, 34, CHEEK)
    c.rect(34, 34, 36, 35, CHEEK)
    # Beard: a cloud of puffs from the cheeks down past the chin.
    for x, y, r in ((20, 39, 4.6), (26, 38, 4.4), (32, 38.5, 4.4), (37, 40, 4.2), (22, 44, 4.8),
                    (28, 45, 5.0), (34, 44, 4.6), (28, 49, 3.8), (17, 43, 3.4), (39, 44, 3.2)):
        c.disc(x, y, r, BEARD)
    # Moustache ridge and the mouth under it.
    c.disc(25.5, 36.2, 2.6, BEARD)
    c.disc(30.5, 36.4, 2.6, BEARD)
    if talk:
        tall = 2 if frame in (2, 5, 7) else 1
        c.rect(27, 38, 29, 38 + tall, MOUTH)
        c.rect(27, 38 + tall, 29, 38 + tall, TONGUE)
    elif happy:
        c.rect(26, 38, 30, 38, MOUTH)
        c.put(25, 37, MOUTH)
        c.put(31, 37, MOUTH)
    # Suit: stripes of teal, yellow and red; ruffled white collar; polka-dot bow tie.
    c.rect(12, 50, 21, 55, SUIT["teal"][1])
    c.rect(12, 50, 13, 55, SUIT["teal"][0])
    c.rect(22, 51, 34, 55, SUIT["yellow"][1])
    c.rect(35, 50, 44, 55, SUIT["red"][1])
    c.rect(43, 50, 44, 55, SUIT["red"][0])
    for x in range(14, 43, 3):
        c.disc(x, 49.5, 1.8, (COLLAR[0], COLLAR[0], COLLAR[1]))
    c.disc(23.5, 52, 3.0, BOW)
    c.disc(32.5, 52, 3.0, BOW)
    c.disc(28, 52, 1.8, (BOW[1], BOW[2], BOW[2]))
    for dx, dy in ((22, 51), (24, 53), (33, 51), (31, 53), (21, 53), (34, 53)):
        c.put(dx, dy, BOW[0])
    if point:
        # Right arm raised, big white glove pointing to the side.
        c.line(41, 52, 48, 42, SUIT["red"][1], 4)
        c.line(42, 50, 47, 43, SUIT["red"][0], 1)
        c.rect(45, 41, 50, 43, SUIT["yellow"][1])
        c.disc(50.5, 38.5, 3.4, (GLOVE[0], GLOVE[0], GLOVE[1]))
        c.rect(52, 36, 55, 37, GLOVE[0])
        c.rect(52, 38, 53, 38, GLOVE[1])
        c.put(49, 41, GLOVE[1])
    return c.image()


def draw_pointer():
    c = Canvas(16, 16)
    c.rect(1, 6, 3, 10, SUIT["yellow"][1])
    c.rect(1, 6, 1, 10, SUIT["yellow"][0])
    c.disc(7, 8.5, 3.6, (GLOVE[0], GLOVE[0], GLOVE[1]))
    c.rect(9, 5, 14, 7, GLOVE[0])
    c.rect(10, 7, 14, 7, GLOVE[1])
    c.rect(8, 11, 9, 11, GLOVE[1])
    return c.image()


def main():
    frames = [draw_pops(i) for i in range(8)]
    sheet = Image.new("RGBA", (S * len(frames), H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * S, 0))
    sheet.save(os.path.join(OUT, "helper.png"))
    p = draw_pointer()
    ptr = Image.new("RGBA", (64, 16), (0, 0, 0, 0))
    for i, im in enumerate((p, p.rotate(-90), p.rotate(180), p.rotate(90))):
        ptr.paste(im, (i * 16, 0))
    ptr.save(os.path.join(OUT, "helper_pointer.png"))
    if len(sys.argv) > 1:
        scale = 8
        big = Image.new("RGBA", (sheet.width * scale, H * scale + 16 * scale), (45, 30, 67, 255))
        sb = sheet.resize((sheet.width * scale, H * scale), Image.NEAREST)
        big.paste(sb, (0, 0), sb)
        pp = ptr.resize((64 * scale, 16 * scale), Image.NEAREST)
        big.paste(pp, (0, H * scale), pp)
        big.save(sys.argv[1])
    print("wrote helper.png and helper_pointer.png to", OUT)


if __name__ == "__main__":
    main()
