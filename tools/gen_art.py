#!/usr/bin/env python3
"""Generates every original pixel-art asset of ORBIT POP.
Run from the project root:  python3 tools/gen_art.py
"""
import math, os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from font5x7 import G

ROOT = os.path.join(os.path.dirname(__file__), "..")
SPR = os.path.join(ROOT, "assets", "sprites")
FNT = os.path.join(ROOT, "assets", "font")
ICO = os.path.join(ROOT, "assets", "icon")
for d in (SPR, FNT, ICO):
    os.makedirs(d, exist_ok=True)

OUT = (38, 28, 66, 255)       # shared dark outline (purple navy)
WHITE = (255, 255, 255, 255)
T = (0, 0, 0, 0)

def rgba(c, a=255):
    return (c[0], c[1], c[2], a)

def new(w, h):
    return Image.new("RGBA", (w, h), T)

def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), rgba(c) if len(c) == 3 else c)

def opaque(img, x, y):
    return 0 <= x < img.width and 0 <= y < img.height and img.getpixel((x, y))[3] > 0

def outline(img, c=OUT, diag=False):
    pts = []
    nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    if diag:
        nb += [(1, 1), (-1, -1), (1, -1), (-1, 1)]
    for y in range(img.height):
        for x in range(img.width):
            if img.getpixel((x, y))[3] == 0 and any(opaque(img, x + dx, y + dy) for dx, dy in nb):
                pts.append((x, y))
    for p in pts:
        img.putpixel(p, c)
    return img

def in_disc(x, y, cx, cy, r):
    return (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r

def shaded_disc(img, cx, cy, r, base, shade, light, light_off=(-0.35, -0.4), light_r=0.38):
    for y in range(img.height):
        for x in range(img.width):
            if not in_disc(x, y, cx, cy, r):
                continue
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            c = base
            if dx * 0.6 + dy * 0.8 > r * 0.45:
                c = shade
            lx, ly = cx + light_off[0] * r, cy + light_off[1] * r
            if (x + 0.5 - lx) ** 2 + (y + 0.5 - ly) ** 2 <= (r * light_r) ** 2:
                c = light
            put(img, x, y, c)

def save(img, name, folder=SPR):
    img.save(os.path.join(folder, name))

def scale(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)

# ---------------------------------------------------------------- character
SKINS = [
    # name, base, shade, light, tip, accessory
    ("poppy",  (255, 212, 60),  (236, 140, 40),  (255, 246, 170), (255, 96, 150), "ball"),
    ("minty",  (110, 230, 160), (36, 166, 120),  (205, 255, 222), (90, 200, 70),  "leaf"),
    ("berry",  (255, 128, 178), (214, 66, 128),  (255, 206, 228), (236, 40, 70),  "heart"),
    ("frosty", (172, 226, 255), (90, 156, 232),  (244, 252, 255), (255, 255, 255), "flake"),
    ("ember",  (255, 122, 58),  (198, 48, 44),   (255, 204, 120), (255, 220, 60), "flame"),
    ("cosmo",  (152, 104, 255), (88, 58, 196),   (214, 186, 255), (255, 224, 70), "star"),
    # premium (STAR PACK)
    ("goldie", (255, 204, 44),  (206, 120, 22),  (255, 244, 160), (255, 236, 90), "crown"),
    ("neon",   (64, 232, 226),  (20, 150, 196),  (206, 255, 252), (255, 80, 200), "bolt"),
    ("panda",  (246, 246, 252), (186, 192, 216), (255, 255, 255), (60, 52, 80),   "ears"),
    # coin skins
    ("cookie", (230, 172, 108), (178, 110, 66),  (252, 216, 160), (255, 120, 150), "chips"),
    ("bubbly", (255, 172, 232), (218, 100, 190), (255, 224, 248), (140, 230, 255), "bubble"),
    ("robo",   (190, 202, 220), (118, 130, 162), (238, 244, 252), (255, 70, 70),   "rivets"),
    ("drake",  (112, 204, 92),  (48, 142, 62),   (196, 242, 160), (255, 250, 230), "horns"),
]
WING_UP = [(2, 8), (1, 7), (2, 7), (1, 6), (0, 6), (0, 5), (1, 5)]
WING_MID = [(2, 9), (1, 9), (0, 9), (1, 8), (2, 8), (0, 8), (1, 10)]
WING_DN = [(2, 10), (1, 10), (2, 11), (1, 11), (0, 11), (0, 12), (1, 12)]

def draw_char(skin, wing, eyes):
    name, base, shade, light, tip, acc = skin
    im = new(16, 16)
    for (x, y) in wing:
        put(im, x + 1, y, (255, 255, 255) if (x + y) % 3 else (206, 234, 255))
    cx, cy, r = 8.5, 9.6, 5.5
    shaded_disc(im, cx, cy, r, base, shade, light)
    # antenna
    if acc not in ("crown", "ears", "horns"):
        put(im, 9, 3, shade); put(im, 10, 2, shade)
    if acc == "ball":
        for p in [(10, 0), (11, 0), (10, 1), (11, 1)]:
            put(im, *p, tip)
        put(im, 10, 0, (255, 200, 225))
    elif acc == "leaf":
        for p in [(10, 1), (11, 1), (11, 0), (12, 0), (9, 1)]:
            put(im, *p, tip)
        put(im, 12, 0, (170, 240, 120))
    elif acc == "heart":
        for p in [(9, 0), (11, 0), (9, 1), (10, 1), (11, 1), (10, 2)]:
            put(im, *p, tip)
        put(im, 9, 0, (255, 150, 160))
    elif acc == "flake":
        for p in [(10, 0), (9, 1), (10, 1), (11, 1), (10, 2)]:
            put(im, *p, tip)
    elif acc == "flame":
        for p in [(10, 1), (11, 1), (10, 2), (11, 0), (10, 0)]:
            put(im, *p, tip)
        put(im, 10, 2, (255, 120, 40)); put(im, 11, 1, (255, 150, 40))
    elif acc == "star":
        for p in [(10, 0), (9, 1), (10, 1), (11, 1), (10, 2)]:
            put(im, *p, tip)
    elif acc == "crown":
        for p in [(7, 3), (8, 2), (9, 3), (10, 2), (11, 3), (7, 2), (11, 2), (7, 4), (8, 4), (9, 4), (10, 4), (11, 4), (8, 3), (10, 3)]:
            put(im, *p, tip)
        put(im, 9, 3, (255, 90, 120)); put(im, 9, 2, (255, 255, 255))
    elif acc == "bolt":
        for p in [(11, 0), (10, 1), (11, 1), (10, 2), (9, 2)]:
            put(im, *p, tip)
    elif acc == "ears":
        for p in [(5, 3), (6, 3), (5, 4), (11, 3), (12, 3), (12, 4)]:
            put(im, *p, tip)
    elif acc in ("chips", "rivets"):
        for p in [(10, 0), (11, 0), (10, 1), (11, 1)]:
            put(im, *p, tip)
        put(im, 10, 0, (255, 255, 255))
    elif acc == "bubble":
        for p in [(10, 0), (11, 0), (9, 1), (12, 1), (10, 2), (11, 2)]:
            put(im, *p, tip)
        put(im, 10, 1, (255, 255, 255))
    elif acc == "horns":
        for p in [(6, 3), (6, 2), (5, 1), (11, 3), (11, 2), (12, 1)]:
            put(im, *p, tip)
    if acc == "chips":
        for p in [(5, 8), (6, 12), (11, 13), (4, 11)]:
            put(im, *p, (110, 60, 40))
    if acc == "rivets":
        for p in [(4, 9), (5, 13), (12, 13)]:
            put(im, *p, (90, 96, 130))
    if acc == "horns":
        for p in [(4, 12), (5, 13), (6, 13)]:
            put(im, *p, (230, 250, 170))
    if acc == "ears":    # panda eye patches
        for p in [(7, 7), (7, 8), (7, 9), (10, 8), (10, 9), (13, 8), (13, 9)]:
            put(im, *p, (90, 80, 110))
    if acc == "flake":   # little red scarf
        for x in range(4, 13):
            if in_disc(x, 13, cx, cy, r):
                put(im, x, 13, (232, 58, 78))
        put(im, 5, 14, (232, 58, 78)); put(im, 4, 14, (190, 36, 60))
    if acc == "star":    # galaxy sparkles
        for p in [(5, 12), (7, 6), (11, 13)]:
            put(im, *p, (255, 255, 255))
    # face (facing right)
    if eyes == "open":
        for ex in (8, 11):
            for y in (7, 8, 9):
                put(im, ex, y, OUT); put(im, ex + 1, y, OUT)
            put(im, ex, 7, WHITE)
    elif eyes == "blink":
        for ex in (8, 11):
            put(im, ex, 9, OUT); put(im, ex + 1, 9, OUT)
    elif eyes == "dead":
        for ex in (8, 11):
            put(im, ex, 7, OUT); put(im, ex + 1, 8, OUT); put(im, ex, 9, OUT)
            put(im, ex + 1, 7, OUT); put(im, ex + 1, 9, OUT)
    elif eyes == "happy":
        for ex in (8, 11):
            put(im, ex, 9, OUT); put(im, ex, 8, OUT); put(im, ex + 1, 7, OUT)
    put(im, 7, 10, (255, 120, 150)); put(im, 13, 10, (255, 120, 150))
    put(im, 10, 11, OUT)
    if eyes == "dead":
        put(im, 9, 11, OUT)
    outline(im)
    return im

for skin in SKINS:
    frames = [(WING_UP, "open"), (WING_MID, "open"), (WING_DN, "open"),
              (WING_MID, "blink"), (WING_MID, "dead"), (WING_UP, "happy")]
    sheet = new(16 * len(frames), 16)
    for i, (w, e) in enumerate(frames):
        sheet.paste(draw_char(skin, w, e), (16 * i, 0))
    save(sheet, "char_%s.png" % skin[0])

# ---------------------------------------------------------------- planet
def planet():
    im = new(64, 64)
    cx = cy = 32
    r = 28.5
    base, shade, light = (255, 142, 108), (226, 86, 98), (255, 196, 150)
    shaded_disc(im, cx, cy, r, base, shade, light, light_off=(-0.42, -0.45), light_r=0.30)
    # terminator band (second shade)
    for y in range(64):
        for x in range(64):
            if in_disc(x, y, cx, cy, r):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                if dx * 0.6 + dy * 0.8 > r * 0.78:
                    put(im, x, y, (190, 64, 100))
    # craters
    for (kx, ky, kr) in [(14, 40, 3.2), (45, 18, 2.6), (47, 44, 3.6), (22, 15, 2.0), (34, 52, 2.2), (54, 31, 1.7)]:
        for y in range(64):
            for x in range(64):
                if in_disc(x, y, kx, ky, kr) and opaque(im, x, y):
                    c = (236, 112, 104) if (y + 0.5) < ky else (250, 168, 132)
                    if not in_disc(x, y, kx, ky, kr - 1.0):
                        c = (214, 82, 96) if (y + 0.5) < ky else (255, 186, 150)
                    put(im, x, y, c)
    # little flowers
    for (fx, fy) in [(9, 28), (55, 22), (27, 58), (40, 8)]:
        put(im, fx, fy, (255, 255, 255)); put(im, fx + 1, fy, (255, 255, 255))
        put(im, fx, fy + 1, (255, 255, 255)); put(im, fx + 1, fy + 1, (255, 224, 80))
    # blush
    for (bx, by) in [(18, 37), (42, 37)]:
        for dx in range(4):
            put(im, bx + dx, by, (255, 110, 140))
        for dx in range(1, 3):
            put(im, bx + dx, by + 1, (255, 110, 140))
    outline(im)
    return im

save(planet(), "planet.png")

def planet_face():
    # 0 eye, 1 eye blink, 2 mouth smile, 3 mouth o, 4 mouth worried
    sheet = new(8 * 5, 8)
    def eye(ox):
        for y in range(1, 6):
            for x in range(2, 6):
                if not ((y in (1, 5)) and (x in (2, 5))):
                    put(sheet, ox + x, y, OUT)
        put(sheet, ox + 3, 2, WHITE); put(sheet, ox + 3, 3, WHITE)
    eye(0)
    for x in range(2, 6):
        put(sheet, 8 + x, 4, OUT)
    put(sheet, 8 + 1, 3, OUT); put(sheet, 8 + 6, 3, OUT)
    # smile
    for x in range(2, 6):
        put(sheet, 16 + x, 4, OUT)
    put(sheet, 16 + 1, 3, OUT); put(sheet, 16 + 6, 3, OUT)
    put(sheet, 16 + 3, 5, (255, 100, 120)); put(sheet, 16 + 4, 5, (255, 100, 120))
    put(sheet, 16 + 3, 4, (255, 100, 120)); put(sheet, 16 + 4, 4, (255, 100, 120))
    # o mouth
    for (x, y) in [(3, 2), (4, 2), (2, 3), (5, 3), (2, 4), (5, 4), (3, 5), (4, 5)]:
        put(sheet, 24 + x, y, OUT)
    for (x, y) in [(3, 3), (4, 3), (3, 4), (4, 4)]:
        put(sheet, 24 + x, y, (150, 40, 70))
    # worried
    for (x, y) in [(1, 5), (2, 4), (3, 4), (4, 4), (5, 4), (6, 5)]:
        put(sheet, 32 + x, y, OUT)
    return sheet

save(planet_face(), "planet_face.png")

# ---------------------------------------------------------------- hazards
def meteor(frame):
    im = new(12, 20)
    # flame tail (pointing up = opposite to travel direction, which is +y)
    flame = [(255, 236, 120), (255, 170, 50), (255, 96, 50)]
    cols = [(4, 7), (3, 8), (5, 6)]
    for y in range(0, 11):
        w = 1 + y // 3 + (frame if y % 2 else 0) % 2
        cxp = 6
        for x in range(cxp - w, cxp + w):
            k = 2 if abs(x + 0.5 - cxp) > w - 1.2 else (1 if y < 7 else 0)
            if y < 2 and (x + frame) % 2:
                continue
            put(im, x, y, flame[k])
    shaded_disc(im, 6, 13.5, 4.6, (164, 132, 120), (104, 78, 92), (214, 190, 170), light_off=(-0.3, 0.1))
    put(im, 7, 15, (120, 92, 100)); put(im, 4, 13, (120, 92, 100)); put(im, 8, 12, (130, 102, 106))
    outline(im)
    return im

sheet = new(24, 20)
sheet.paste(meteor(0), (0, 0)); sheet.paste(meteor(1), (12, 0))
save(sheet, "meteor.png")

def spiky(frame):
    im = new(17, 17)
    c = 8.5
    body, shade, light = (196, 84, 236), (130, 48, 190), (236, 170, 255)
    tip = (255, 120, 200)
    for i in range(8):
        a = i * math.pi / 4 + (math.pi / 8 if frame else 0)
        for k, rr in enumerate((4.6, 5.6, 6.6, 7.5)):
            x = int(math.floor(c + math.cos(a) * rr)); y = int(math.floor(c + math.sin(a) * rr))
            put(im, x, y, tip if k >= 2 else body)
            if k == 0:
                for d in (-0.32, 0.32):
                    put(im, int(math.floor(c + math.cos(a + d) * 5.6)), int(math.floor(c + math.sin(a + d) * 5.6)), body)
    shaded_disc(im, c, c, 4.8, body, shade, light)
    # angry eyes
    for (x, y) in [(6, 8), (6, 9), (10, 8), (10, 9)]:
        put(im, x, y, WHITE)
    put(im, 7, 9, OUT); put(im, 10, 9, OUT)
    put(im, 5, 7, OUT); put(im, 6, 7, OUT); put(im, 10, 7, OUT); put(im, 11, 7, OUT)
    put(im, 8, 11, OUT); put(im, 7, 11, OUT); put(im, 9, 11, OUT)
    outline(im)
    return im

sheet = new(34, 17)
sheet.paste(spiky(0), (0, 0)); sheet.paste(spiky(1), (17, 0))
save(sheet, "spiky.png")

def node():
    im = new(10, 10)
    shaded_disc(im, 5, 5, 4.2, (120, 136, 180), (70, 78, 130), (200, 214, 240))
    for (x, y) in [(4, 4), (5, 4), (4, 5), (5, 5)]:
        put(im, x, y, (255, 240, 110))
    put(im, 4, 4, WHITE)
    outline(im)
    return im

save(node(), "node.png")

def bubble():
    im = new(14, 14)
    c, r = 7, 6.0
    for y in range(14):
        for x in range(14):
            if in_disc(x, y, c, c, r):
                put(im, x, y, (180, 240, 255, 110))
                if not in_disc(x, y, c, c, r - 1.1):
                    put(im, x, y, (120, 220, 255, 255))
    for p in [(4, 4), (5, 3), (4, 5)]:
        put(im, *p, WHITE)
    # star inside
    for p in [(7, 5), (6, 7), (7, 7), (8, 7), (7, 6), (5, 7), (9, 7), (6, 8), (8, 8), (6, 9), (8, 9)]:
        put(im, *p, (255, 222, 70))
    outline(im, (40, 110, 170, 255))
    return im

save(bubble(), "bubble.png")

# ---------------------------------------------------------------- background
def cloud(w, h, blobs):
    im = new(w, h)
    for (bx, by, br) in blobs:
        for y in range(h):
            for x in range(w):
                if in_disc(x, y, bx, by, br):
                    put(im, x, y, (255, 255, 255))
    for y in range(h):
        for x in range(w):
            if opaque(im, x, y) and not opaque(im, x, y + 2):
                put(im, x, y, (214, 238, 255))
    for y in range(h):
        for x in range(w):
            if opaque(im, x, y) and not opaque(im, x, y + 1):
                put(im, x, y, (186, 222, 252))
    return im

save(cloud(46, 20, [(10, 13, 6.5), (20, 9, 8), (31, 11, 7), (39, 14, 5.5), (24, 15, 5)]), "cloud_big.png")
save(cloud(30, 14, [(8, 9, 5), (16, 6, 5.8), (23, 9, 4.6)]), "cloud_mid.png")
save(cloud(18, 9, [(5, 6, 3.4), (10, 4, 3.8), (14, 6, 3)]), "cloud_small.png")

def floor_tile():
    im = new(32, 22)
    for (bx, by, br) in [(4, 10, 7), (14, 6, 7.5), (24, 9, 7), (32, 7, 7.5), (0, 7, 7.5)]:
        for y in range(22):
            for x in range(32):
                if in_disc(x, y, bx, by, br):
                    put(im, x, y, (255, 255, 255))
    for y in range(9, 22):
        for x in range(32):
            put(im, x, y, (255, 255, 255))
    for y in range(22):
        for x in range(32):
            if opaque(im, x, y) and y > 12:
                put(im, x, y, (226, 244, 255))
            if opaque(im, x, y) and y > 17:
                put(im, x, y, (204, 232, 255))
    return im

save(floor_tile(), "cloud_floor.png")

def island(w, flip):
    im = new(w, 16)
    for x in range(w):
        top = 4 + (1 if x in (0, w - 1) else 0)
        depth = int(4 + 6 * math.sin(math.pi * (x + 0.5) / w) + (1 if x % 3 == 0 else 0))
        for y in range(top, top + depth):
            put(im, x, y, (196, 158, 168) if y > top + 2 else (164, 220, 150))
        put(im, x, top, (140, 210, 140))
    tx = w // 3 if not flip else 2 * w // 3
    for y in range(0, 4):
        put(im, tx, y + 1, (150, 120, 140))
    for (dx, dy) in [(-1, 0), (0, 0), (1, 0), (-2, 1), (-1, 1), (0, 1), (1, 1), (2, 1), (-1, -1), (0, -1), (1, -1)]:
        put(im, tx + dx, 1 + dy, (120, 200, 140))
    return im

save(island(26, False), "island_a.png")
save(island(18, True), "island_b.png")

def sun():
    im = new(30, 30)
    for y in range(30):
        for x in range(30):
            if in_disc(x, y, 15, 15, 14):
                put(im, x, y, (255, 248, 196, 90))
            if in_disc(x, y, 15, 15, 10):
                put(im, x, y, (255, 238, 140))
            if in_disc(x, y, 13, 13, 6):
                put(im, x, y, (255, 250, 210))
    return im

save(sun(), "sun.png")

# ---------------------------------------------------------------- font (BMFont)
def glyph_w(ch):
    if ch in ".,:!'\u00a1":
        return 3
    if ch == " ":
        return 4
    return 5

from font5x7 import ACCENTS, ACCENTED, CEDILLA

def glyph_rows(c):
    """13-row glyph: 2 accent rows, 7 letter rows, 2 cedilla rows (outline added later)."""
    blank = "....."
    if c in ACCENTED:
        base, acc = ACCENTED[c]
        return ACCENTS[acc] + G[base] + [blank, blank]
    if c in CEDILLA:
        return [blank, blank] + G[CEDILLA[c]] + ["..#..", ".##.."]
    return [blank, blank] + G[c] + [blank, blank]

def build_font(name="pixel", outlined=True):
    chars = list(G.keys()) + list(ACCENTED.keys()) + list(CEDILLA.keys())
    cols = 16
    cw, ch_ = 7, 13
    rows = (len(chars) + cols - 1) // cols
    im = new(cols * cw, rows * ch_)
    lines = []
    for i, c in enumerate(chars):
        gx, gy = (i % cols) * cw, (i // cols) * ch_
        glyph = glyph_rows(c)
        gw = glyph_w(c)
        x0 = 0 if gw == 5 else (1 if c in ".,:!'\u00a1" else 0)
        cell = new(cw, ch_)
        for yy, row in enumerate(glyph):
            for xx, v in enumerate(row):
                if v == "#":
                    put(cell, xx + 1 - x0, yy + 1, WHITE)
        if c != " " and outlined:
            outline(cell, OUT, diag=True)
        im.paste(cell, (gx, gy))
        lines.append("char id=%d x=%d y=%d width=%d height=%d xoffset=-1 yoffset=-3 xadvance=%d page=0 chnl=15"
                     % (ord(c), gx, gy, gw + 2, ch_, gw + 1))
    im.save(os.path.join(FNT, name + ".png"))
    with open(os.path.join(FNT, name + ".fnt"), "w", encoding="utf-8") as f:
        f.write('info face="OrbitPop" size=8 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=0,0\n')
        f.write("common lineHeight=10 base=7 scaleW=%d scaleH=%d pages=1 packed=0\n" % (im.width, im.height))
        f.write('page id=0 file="%s.png"\n' % name)
        f.write("chars count=%d\n" % len(chars))
        f.write("\n".join(lines) + "\n")

build_font()
build_font("pixel_plain", outlined=False)   # for dark text on light panels / buttons

def text_img(s, k, fill_top, fill_bot, out_w=2, shadow=(30, 18, 60)):
    """Big chunky logo text rendered from the pixel glyphs."""
    gw = sum(glyph_w(c) + 1 for c in s) - 1
    base = new(gw * k, 7 * k)
    x = 0
    for c in s:
        for yy, row in enumerate(G[c]):
            for xx, v in enumerate(row):
                if v == "#":
                    col = fill_top if yy < 3 else fill_bot
                    if yy == 0:
                        col = tuple(min(255, v2 + 40) for v2 in fill_top)
                    for a in range(k):
                        for b in range(k):
                            put(base, x + xx * k + a, yy * k + b, col)
        x += (glyph_w(c) + 1) * k
    pad = out_w + 3
    im = new(base.width + pad * 2, base.height + pad * 2 + 3)
    sh = new(im.width, im.height)
    sh.paste(base, (pad, pad + 3))
    for _ in range(out_w):
        outline(sh, rgba(shadow), diag=True)
    shp = sh.load()
    for y in range(sh.height):
        for x in range(sh.width):
            if shp[x, y][3]:
                shp[x, y] = rgba(shadow)
    im.alpha_composite(sh)
    fg = new(im.width, im.height)
    fg.paste(base, (pad, pad))
    for _ in range(out_w):
        outline(fg, OUT, diag=True)
    im.alpha_composite(fg)
    return im

orbit = text_img("ORBIT", 4, (255, 255, 255), (206, 232, 255))
pop = text_img("POP", 5, (255, 236, 90), (255, 160, 60))
logo = new(max(orbit.width, pop.width), orbit.height + pop.height - 3)
logo.alpha_composite(orbit, ((logo.width - orbit.width) // 2, 0))
logo.alpha_composite(pop, ((logo.width - pop.width) // 2, orbit.height - 3))
save(logo, "logo.png")

# ---------------------------------------------------------------- UI
def button(fill, light, dark, pressed=False):
    im = new(16, 16)
    top = 1 if pressed else 0
    bottom = 15 if pressed else 13
    for y in range(top, 16):
        for x in range(16):
            corner = (x in (0, 15) and y in (top, 15)) or (x in (0, 15) and y == bottom + 1 and not pressed)
            if corner:
                continue
            if x in (0, 15) or y == top or y == 15:
                put(im, x, y, OUT)
            elif y > bottom:
                put(im, x, y, dark)
            elif y == top + 1 and 1 < x < 14:
                put(im, x, y, light)
            else:
                put(im, x, y, fill)
    if not pressed:
        for x in range(1, 15):
            put(im, x, bottom + 1, dark)
    put(im, 1, top + 1, fill); put(im, 14, top + 1, fill)
    return im

for name, f, l, d in [("yellow", (255, 214, 64), (255, 246, 170), (222, 128, 40)),
                      ("white", (250, 250, 255), (255, 255, 255), (156, 176, 220)),
                      ("pink", (255, 128, 178), (255, 206, 228), (196, 58, 120)),
                      ("green", (124, 226, 104), (210, 255, 180), (40, 150, 90))]:
    save(button(f, l, d), "btn_%s.png" % name)
    save(button(f, l, d, True), "btn_%s_pressed.png" % name)

def panel():
    im = new(16, 16)
    for y in range(16):
        for x in range(16):
            if (x in (0, 15) and y in (0, 15)):
                continue
            if x in (0, 15) or y in (0, 15):
                put(im, x, y, OUT)
            elif y >= 13:
                put(im, x, y, (214, 200, 236))
            else:
                put(im, x, y, (255, 251, 242))
    put(im, 1, 1, OUT); put(im, 14, 1, OUT); put(im, 1, 14, OUT); put(im, 14, 14, OUT)
    return im

save(panel(), "panel.png")

def card(sel):
    im = new(12, 12)
    edge = (255, 200, 40) if sel else OUT
    for y in range(12):
        for x in range(12):
            if x in (0, 11) and y in (0, 11):
                continue
            if x in (0, 11) or y in (0, 11):
                put(im, x, y, edge)
            else:
                put(im, x, y, (236, 246, 255) if not sel else (255, 247, 210))
    if sel:
        for x in range(1, 11):
            put(im, x, 1, (255, 226, 120)); put(im, x, 10, (255, 226, 120))
        for y in range(1, 11):
            put(im, 1, y, (255, 226, 120)); put(im, 10, y, (255, 226, 120))
    return im

save(card(False), "card.png")
save(card(True), "card_sel.png")

ICONS = {
    "sound_on": ["...#.....", "..##..#..", "####...#.", "####.#.#.", "####.#.#.", "####...#.", "..##..#..", "...#....."],
    "sound_off": ["...#.....", "..##.....", "####.#.#.", "####..#..", "####..#..", "####.#.#.", "..##.....", "...#....."],
    "home": ["....#....", "...###...", "..#####..", ".#######.", "..#####..", "..##.##..", "..##.##..", "..##.##.."],
    "retry": ["..####...", ".#....#..", "#......#.", "#.....###", "#......#.", "#........", ".#....#..", "..####..."],
    "back": ["...#.....", "..##.....", ".#######.", "########.", ".#######.", "..##.....", "...#.....", "........."],
    "lock": ["..###....", ".#...#...", ".#...#...", "#######..", "###.###..", "###.###..", "#######..", "........."],
    "skins": ["..#.#....", "..###....", ".#####...", "##.#.##..", "#######..", "#######..", ".#####...", "........."],
    "star": ["....#....", "...###...", "#########", ".#######.", "..#####..", ".###.###.", ".#.....#.", "........."],
    "cart": ["#........", "########.", ".#######.", ".######..", ".#####...", ".........", "..#..#...", "........."],
    "noads": ["#.......#", ".#.###.#.", "..#...#..", ".#.#.#.#.", ".#..#..#.", ".#.#.#.#.", "..#...#..", "#..###..#"],
    "video": ["#######..", "#.....#.#", "#..#..###", "#..##.###", "#..#..###", "#.....#.#", "#######..", "........."],
    "crown": ["#...#...#", "##.###.##", "#########", "#########", ".#######.", ".........", ".........", "........."],
}

for name, rows in ICONS.items():
    im = new(11, 10)
    for y, row in enumerate(rows):
        for x, v in enumerate(row):
            if v == "#":
                col = WHITE
                if name == "star":
                    col = (255, 220, 60)
                if name == "crown":
                    col = (255, 210, 50)
                if name == "lock":
                    col = (255, 210, 90)
                if name == "noads":
                    col = (255, 110, 120)
                put(im, x + 1, y + 1, col)
    outline(im, OUT, diag=True)
    save(im, "icon_%s.png" % name)

# ---------------------------------------------------------------- app icon
def app_icon(size, with_bg=True, fg_scale=1.0):
    s = 48
    im = new(s, s)
    if with_bg:
        for y in range(s):
            t = y / s
            col = (int(80 + 90 * t), int(168 + 60 * t), 255)
            for x in range(s):
                put(im, x, y, col)
        im.alpha_composite(cloud(18, 9, [(5, 6, 3.4), (10, 4, 3.8), (14, 6, 3)]), (2, 34))
        im.alpha_composite(cloud(18, 9, [(5, 6, 3.4), (10, 4, 3.8), (14, 6, 3)]), (30, 6))
    pl = new(34, 34)
    shaded_disc(pl, 17, 17, 13.5, (255, 142, 108), (226, 86, 98), (255, 196, 150), light_off=(-0.42, -0.45), light_r=0.3)
    for (x, y) in [(12, 15), (12, 16), (13, 15), (13, 16), (20, 15), (20, 16), (21, 15), (21, 16)]:
        put(pl, x, y, OUT)
    put(pl, 12, 15, WHITE); put(pl, 20, 15, WHITE)
    for x in range(15, 19):
        put(pl, x, 19, OUT)
    put(pl, 10, 18, (255, 110, 140)); put(pl, 23, 18, (255, 110, 140))
    outline(pl)
    im.alpha_composite(pl, (7, 10))
    ch = draw_char(SKINS[0], WING_UP, "open")
    im.alpha_composite(ch, (28, 2))
    return im.resize((size, size), Image.NEAREST)

app_icon(192).save(os.path.join(ICO, "icon_192.png"))
app_icon(512).save(os.path.join(ICO, "icon_512.png"))
# adaptive icon: 432x432 layers, artwork inside the 66% safe zone
fg = new(72, 72)
fg.alpha_composite(app_icon(48, with_bg=False), (12, 12))
fg.resize((432, 432), Image.NEAREST).save(os.path.join(ICO, "icon_fg_432.png"))
bg = new(108, 108)
for y in range(108):
    for x in range(108):
        t = y / 108
        put(bg, x, y, (int(80 + 90 * t), int(168 + 60 * t), 255))
bg.resize((432, 432), Image.NEAREST).save(os.path.join(ICO, "icon_bg_432.png"))
def saw(frame):
    im = new(17, 17)
    c = 8.5
    for i in range(10):
        a = i * math.pi / 5 + (math.pi / 10 if frame else 0)
        for rr in (6.0, 7.2):
            put(im, int(math.floor(c + math.cos(a) * rr)), int(math.floor(c + math.sin(a) * rr)), (230, 236, 248))
    shaded_disc(im, c, c, 5.6, (196, 206, 226), (126, 136, 170), (250, 252, 255))
    shaded_disc(im, c, c, 2.0, (255, 90, 90), (200, 40, 60), (255, 180, 180))
    outline(im)
    return im

sheet = new(34, 17)
sheet.paste(saw(0), (0, 0)); sheet.paste(saw(1), (17, 0))
save(sheet, "saw.png")

# ---------------------------------------------------------------- economy / cosmetics
import colorsys
def hue_shift(img, deg, sat=1.0, val=1.0):
    out = img.copy(); px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0 or (r, g, b, a) == OUT or (r, g, b) == (255, 255, 255):
                continue
            h, s_, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            h = (h + deg / 360.0) % 1.0
            r2, g2, b2 = colorsys.hsv_to_rgb(h, min(1, s_ * sat), min(1, v * val))
            px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return out

base_planet = planet()
for name, deg, sat in [("violet", 255, 0.9), ("mint", 140, 0.85), ("gold", 30, 1.1)]:
    hue_shift(base_planet, deg, sat).save(os.path.join(SPR, "planet_%s.png" % name))

def trail_icon(kind):
    im = new(16, 16)
    rainbow = [(255, 90, 90), (255, 170, 60), (255, 230, 70), (110, 220, 110), (90, 170, 255), (170, 110, 255)]
    for i in range(6):
        x, y = 2 + i * 2, 12 - i * 2
        if kind == "classic":
            c = (255, 212, 60) if i % 2 == 0 else (255, 255, 255)
            for dx in range(max(1, i // 2) + 1):
                put(im, x + dx, y, c); put(im, x + dx, y + 1, c)
        elif kind == "sparkle":
            c = (255, 255, 255) if i % 2 else (255, 240, 140)
            put(im, x, y, c); put(im, x + 1, y, c); put(im, x, y - 1, c); put(im, x - 1, y, c); put(im, x, y + 1, c)
        elif kind == "rainbow":
            for dy in range(2):
                for dx in range(2):
                    put(im, x + dx, y + dy, rainbow[i])
        elif kind == "hearts" and i % 2 == 0:
            for (dx, dy) in [(0, 0), (2, 0), (0, 1), (1, 1), (2, 1), (1, 2)]:
                put(im, x + dx - 1, y + dy - 1, (255, 100, 150))
        elif kind == "stars" and i % 2 == 0:
            for (dx, dy) in [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)]:
                put(im, x + dx - 1, y + dy - 1, (255, 220, 60))
    outline(im)
    return im

for k in ["classic", "sparkle", "rainbow", "hearts", "stars"]:
    save(trail_icon(k), "trail_%s.png" % k)

WORLD_ICON = {"sky": ((70, 152, 255), (176, 230, 255), (255, 142, 108)),
              "sunset": ((255, 120, 110), (255, 214, 140), (176, 120, 255)),
              "candy": ((255, 150, 200), (255, 222, 240), (120, 226, 180)),
              "night": ((30, 40, 110), (90, 90, 180), (255, 206, 80)),
              "lagoon": ((40, 190, 200), (170, 250, 230), (255, 142, 108))}
for k, (top, bot, pc) in WORLD_ICON.items():
    im = new(16, 16)
    for y in range(1, 15):
        t = (y - 1) / 13
        c = tuple(int(top[j] + (bot[j] - top[j]) * t) for j in range(3))
        for x in range(1, 15):
            put(im, x, y, c)
    if k == "night":
        for p in [(3, 3), (12, 2), (10, 5), (4, 11)]:
            put(im, *p, (255, 255, 255))
    for y in range(16):
        for x in range(16):
            if in_disc(x, y, 8, 9, 4.2):
                put(im, x, y, pc)
    put(im, 6, 7, tuple(min(255, v + 60) for v in pc))
    outline(im)
    save(im, "world_%s.png" % k)

MORE_ICONS = {
    "coin": ["..###..", ".#####.", "##.####", "##.####", "##.####", ".#####.", "..###..", "......."],
    "gift": ["..#.#....", "...#.....", "#########", "#########", ".###.###.", ".###.###.", ".###.###.", ".#######."],
    "shield": ["#########", "#########", "#########", ".#######.", ".#######.", "..#####..", "...###...", "....#...."],
    "rush": ["..###....", ".#...#...", "#.#...#..", "#.....#..", ".#...#.#.", "..###.###", "......###", "........."],
    "trail": [".........", "......##.", "....####.", "..######.", "######...", "####.....", "##.......", "........."],
    "world": ["..#####..", ".##...##.", "##.#...##", "#...##..#", "#..#....#", "##....###", ".##..###.", "..#####.."],
    "teleport": ["..####...", ".#....#..", "#..##..#.", "#.#..#.#.", "#.#.#..#.", "#..#..#..", ".#....#..", "..####..."],
    "mission": ["#######..", "#.....#..", "#.###.#..", "#.....#..", "#.##..#..", "#....##..", "#....#...", "######..."],
    "trophy": ["#######..", "#######..", ".#####...", "..###....", "...#.....", "..###....", ".#####...", "........."],
    "gear": ["...#.....", ".#####...", ".##.##...", "##...##..", ".##.##...", ".#####...", "...#.....", "........."],
    "share": ["....##...", "...###...", "..#.##...", ".#...#...", "#......#.", "#......#.", "########.", "........."],
    "globe": ["..###....", ".#.#.#...", "#..#..#..", "#######..", "#..#..#..", ".#.#.#...", "..###....", "........."],
    "left": ["...#.....", "..##.....", ".###.....", "####.....", ".###.....", "..##.....", "...#.....", "........."],
    "right": ["#........", "##.......", "###......", "####.....", "###......", "##.......", "#........", "........."],
}
MORE_COL = {"coin": (255, 206, 50), "gift": (255, 110, 160), "shield": (120, 220, 255), "rush": (140, 230, 255),
            "trail": (255, 230, 90), "teleport": (200, 140, 255), "mission": (255, 240, 200), "trophy": (255, 206, 50),
            "gear": (220, 226, 240), "share": (140, 230, 160), "globe": (120, 200, 255), "world": (120, 220, 140), "left": (255, 255, 255), "right": (255, 255, 255)}
for name, rows in MORE_ICONS.items():
    im = new(len(rows[0]) + 2, len(rows) + 2)
    for y, row in enumerate(rows):
        for x, v in enumerate(row):
            if v == "#":
                put(im, x + 1, y + 1, MORE_COL[name])
    if name == "coin":
        put(im, 3, 2, (255, 250, 200)); put(im, 2, 3, (255, 250, 200))
    if name == "shield":
        put(im, 3, 2, (230, 250, 255)); put(im, 3, 3, (230, 250, 255))
    if name == "gift":
        for yy in range(3, 9):
            put(im, 5, yy, (255, 230, 90))
    outline(im, OUT, diag=True)
    save(im, "icon_%s.png" % name)
print("art ok")
