"""Generate original 22px pixel-art Endless finishes from the same kit as gen_ui.py.

Run: python tools/art/gen_skins.py
Output: assets/ui/skin_<finish>_<color>.png at 4x nearest-neighbor scale.
Each face keeps a color cue, while silhouette, reflectivity and surface marks
identify the material. Source is deterministic and does not use external art.
"""
from PIL import Image, ImageDraw

import gen_ui as kit


FINISHES = (
    "glass", "crystal", "neon", "gold", "marble", "cyberpunk", "wood",
    "candy", "lava", "ice", "chrome", "aurora", "starfall",
)
COLORS = ("red", "orange", "yellow", "green", "blue", "purple")
INK = kit.INK
WHITE = kit.WHITE


def blend(a, b, amount):
    return tuple(round(a[i] * (1 - amount) + b[i] * amount) for i in range(3)) + (255,)


def rgba(c, a):
    return c[:3] + (a,)


def face(base, light, dark, *, outline=INK, cut=3):
    im = kit.img(22, 22)
    kit.fill_shape(im, 0, 0, 22, 22, cut, outline)
    kit.fill_shape(im, 1, 1, 20, 20, cut, base)
    for x in range(4, 18):
        kit.px(im, x, 2, light)
        kit.px(im, x, 19, dark)
    for y in range(4, 18):
        kit.px(im, 2, y, light)
        kit.px(im, 19, y, dark)
    return im


def make(finish, color):
    hi, light, hue, dark, darker = kit.BLOCKS[color]
    pearl = blend(hue, WHITE, 0.55)
    shadow = blend(hue, INK, 0.66)
    draw = None

    if finish == "glass":
        im = kit.img(22, 22)
        kit.fill_shape(im, 0, 0, 22, 22, 3, rgba(shadow, 220))
        kit.fill_shape(im, 2, 2, 18, 18, 3, rgba(hue, 95))
        kit.outline_shape(im, 1, 1, 20, 20, 3, rgba(pearl, 240))
        kit.rect(im, 4, 4, 11, 2, rgba(WHITE, 220))
        kit.rect(im, 4, 6, 2, 6, rgba(WHITE, 195))
        kit.hline(im, 7, 16, 10, rgba(hue, 220))
        kit.px(im, 16, 7, WHITE)
        return im

    if finish == "crystal":
        im = face(shadow, pearl, darker)
        draw = ImageDraw.Draw(im)
        draw.polygon([(3, 14), (9, 3), (18, 5), (18, 16), (11, 19)], fill=rgba(pearl, 255))
        draw.polygon([(9, 3), (18, 5), (12, 10)], fill=rgba(hi, 255))
        draw.polygon([(3, 14), (12, 10), (11, 19)], fill=rgba(hue, 255))
        draw.polygon([(12, 10), (18, 5), (18, 16), (11, 19)], fill=rgba(light, 255))
        draw.line([(9, 3), (12, 10), (3, 14)], fill=rgba(WHITE, 255), width=1)
        draw.line([(12, 10), (18, 16)], fill=rgba(shadow, 255), width=1)
        kit.px(im, 7, 5, WHITE)
        return im

    if finish == "neon":
        im = face((20, 25, 43, 255), (40, 52, 76, 255), (9, 13, 29, 255))
        kit.outline_shape(im, 2, 2, 18, 18, 2, hue)
        kit.outline_shape(im, 4, 4, 14, 14, 2, rgba(pearl, 240))
        kit.rect(im, 6, 9, 10, 4, rgba(shadow, 255))
        kit.hline(im, 7, 10, 8, hi)
        for x in (6, 15):
            kit.rect(im, x, 6, 1, 3, hue)
        return im

    if finish == "gold":
        metal = (223, 160, 42, 255)
        im = face(metal, (255, 231, 125, 255), (131, 75, 19, 255))
        kit.outline_shape(im, 3, 3, 16, 16, 2, (255, 207, 80, 255))
        draw = ImageDraw.Draw(im)
        draw.polygon([(11, 5), (17, 11), (11, 17), (5, 11)], fill=shadow)
        draw.polygon([(11, 6), (16, 11), (11, 16), (6, 11)], fill=hue)
        draw.polygon([(11, 6), (16, 11), (11, 11)], fill=hi)
        kit.hline(im, 5, 4, 12, (255, 245, 177, 255))
        return im

    if finish == "marble":
        stone = blend(pearl, (244, 239, 225, 255), 0.7)
        im = face(stone, WHITE, blend(stone, shadow, 0.32))
        draw = ImageDraw.Draw(im)
        draw.line([(4, 17), (7, 13), (10, 14), (12, 9), (17, 8), (19, 4)], fill=blend(hue, shadow, 0.48), width=2)
        draw.line([(5, 6), (8, 8), (12, 5)], fill=rgba(shadow, 190), width=1)
        draw.line([(13, 17), (16, 15), (18, 17)], fill=rgba(hue, 230), width=1)
        kit.rect(im, 4, 4, 5, 1, rgba(WHITE, 255))
        return im

    if finish == "cyberpunk":
        im = face((30, 25, 51, 255), (73, 57, 101, 255), (15, 11, 30, 255))
        kit.rect(im, 4, 7, 14, 9, (17, 21, 40, 255))
        kit.rect(im, 6, 9, 10, 5, shadow)
        kit.rect(im, 7, 10, 8, 3, hue)
        kit.hline(im, 4, 5, 8, (93, 241, 247, 255))
        kit.vline(im, 17, 5, 10, (245, 79, 183, 255))
        for x in (5, 9, 13, 17):
            kit.px(im, x, 18, (93, 241, 247, 255))
        return im

    if finish == "wood":
        im = face((151, 91, 47, 255), (205, 141, 77, 255), (77, 43, 37, 255))
        draw = ImageDraw.Draw(im)
        for y in (5, 9, 14, 18):
            draw.line([(4, y), (10, y - 1), (17, y)], fill=(94, 52, 36, 255), width=1)
        draw.ellipse((8, 7, 14, 13), outline=(72, 44, 33, 255), width=1)
        kit.rect(im, 4, 4, 4, 3, hue)
        kit.px(im, 17, 5, (231, 190, 110, 255))
        kit.px(im, 5, 17, (231, 190, 110, 255))
        return im

    if finish == "candy":
        im = face(pearl, WHITE, blend(hue, shadow, 0.26))
        draw = ImageDraw.Draw(im)
        for x in (-4, 2, 8, 14):
            draw.line([(x, 18), (x + 12, 4)], fill=rgba(WHITE, 245), width=3)
            draw.line([(x + 1, 18), (x + 13, 4)], fill=rgba(hue, 255), width=1)
        kit.outline_shape(im, 1, 1, 20, 20, 3, rgba(hi, 255))
        for x, y in ((6, 6), (16, 9), (10, 16)):
            kit.px(im, x, y, WHITE)
        return im

    if finish == "lava":
        im = face((42, 34, 40, 255), (75, 53, 54, 255), (14, 13, 22, 255))
        draw = ImageDraw.Draw(im)
        cracks = [(4, 5), (8, 9), (5, 14), (12, 17), (18, 13)]
        draw.line(cracks, fill=shadow, width=4)
        draw.line(cracks, fill=hue, width=2)
        draw.line([(8, 9), (15, 6), (18, 7)], fill=hi, width=2)
        for x, y in ((6, 13), (12, 17), (16, 7)):
            kit.px(im, x, y, (255, 241, 151, 255))
        return im

    if finish == "ice":
        frost = blend(pearl, (184, 230, 255, 255), 0.6)
        im = face(frost, WHITE, blend(hue, (74, 130, 189, 255), 0.55))
        draw = ImageDraw.Draw(im)
        draw.polygon([(4, 5), (12, 3), (17, 7), (8, 11)], fill=rgba(WHITE, 220))
        draw.polygon([(8, 11), (17, 7), (18, 18), (12, 17)], fill=rgba(hue, 210))
        draw.line([(5, 17), (11, 10), (16, 11), (19, 5)], fill=rgba(WHITE, 255), width=1)
        draw.line([(11, 10), (11, 5)], fill=rgba(shadow, 150), width=1)
        return im

    if finish == "chrome":
        im = face((138, 152, 176, 255), (245, 249, 255, 255), (48, 61, 82, 255))
        kit.rect(im, 3, 4, 16, 3, WHITE)
        kit.rect(im, 3, 8, 16, 4, (56, 70, 94, 255))
        kit.rect(im, 3, 12, 16, 3, hue)
        kit.rect(im, 3, 16, 16, 2, (218, 233, 249, 255))
        kit.hline(im, 5, 5, 11, (255, 255, 255, 255))
        return im

    if finish == "aurora":
        im = face(blend(hue, (116, 221, 197, 255), 0.42), WHITE, shadow)
        draw = ImageDraw.Draw(im)
        draw.line([(3, 16), (7, 12), (12, 14), (18, 6)], fill=(122, 254, 210, 255), width=3)
        draw.line([(4, 9), (9, 6), (13, 8), (18, 4)], fill=(233, 166, 255, 255), width=2)
        kit.px(im, 16, 15, WHITE)
        return im

    if finish == "starfall":
        im = face((33, 38, 75, 255), (89, 100, 165, 255), (13, 17, 43, 255))
        kit.rect(im, 5, 15, 12, 2, hue)
        for x, y in ((7, 6), (15, 8), (11, 12)):
            kit.hline(im, x - 1, y, 3, WHITE)
            kit.vline(im, x, y - 1, 3, WHITE)
        kit.px(im, 17, 5, (255, 222, 130, 255))
        return im

    raise ValueError(finish)


def main():
    count = 0
    for finish in FINISHES:
        for color in COLORS:
            image = make(finish, color)
            kit.save(f"skin_{finish}_{color}", image)
            count += 1
    print(f"wrote {count} original pixel-art finish sprites to {kit.OUT}")


if __name__ == "__main__":
    main()
