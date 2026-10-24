#!/usr/bin/env python3
"""Play Store screenshots (1080x1920): a big pixel caption on top of a raw game frame.
Raw frames come from tests/shots_store.gd (one folder per language):
    python3 tools/gen_store_shots.py <raw_dir> <lang> <out_dir>
"""
import os, sys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
from font5x7 import G, ACCENTS, ACCENTED

W, H = 1080, 1920
OUT = (38, 28, 66)
# frame file, background top/bottom, caption per language
SHOTS = [
    ("g1_9", (62, 120, 214), (120, 190, 250), {"en": "ONE TAP TO FLIP YOUR ORBIT", "es": "UN TOQUE PARA GIRAR AL REVÉS"}),
    ("g2_7", (28, 24, 70), (70, 60, 140), {"en": "DODGE, SWITCH ORBITS, SURVIVE", "es": "ESQUIVA Y CAMBIA DE ÓRBITA"}),
    ("g3_8", (214, 110, 60), (250, 190, 110), {"en": "10 WORLDS, UP TO 3 PLANETS", "es": "10 MUNDOS, HASTA 3 PLANETAS"}),
    ("g4_6", (110, 60, 160), (220, 110, 170), {"en": "GRAB COINS ON EVERY RUN", "es": "RECOGE MONEDAS EN CADA PARTIDA"}),
    ("u5_abilities", (30, 80, 150), (90, 160, 230), {"en": "LEVEL UP 7 POWERS", "es": "SUBE DE NIVEL 7 HABILIDADES"}),
    ("u6_skins", (40, 120, 90), (110, 200, 150), {"en": "26 SKINS AND 20 TRAILS", "es": "26 SKINS Y 20 ESTELAS"}),
    ("u7_missions", (170, 90, 30), (240, 170, 70), {"en": "DAILY MISSIONS AND REWARDS", "es": "MISIONES Y PREMIOS DIARIOS"}),
    ("u8_ranking", (120, 40, 90), (220, 90, 140), {"en": "CLIMB THE WORLD RANKING", "es": "SUBE EN EL RANKING MUNDIAL"}),
]


def rows(c):
    blank = "....."
    if c in ACCENTED:
        base, acc = ACCENTED[c]
        return ACCENTS[acc] + G[base]
    return [blank, blank] + G.get(c, G[" "])


def gw(c):
    return 3 if c in ".,:!'¡" else (4 if c == " " else 5)


def text_mask(s, k):
    w = sum((gw(c) + 1) for c in s) - 1
    im = Image.new("L", (w * k, 9 * k), 0)
    d = ImageDraw.Draw(im)
    x = 0
    for c in s:
        for yy, row in enumerate(rows(c)):
            for xx, v in enumerate(row[:gw(c)] if gw(c) < 5 else row):
                if v == "#":
                    d.rectangle((x + xx * k, yy * k, x + xx * k + k - 1, yy * k + k - 1), fill=255)
        x += (gw(c) + 1) * k
    return im


def dilate(mask, r):
    out = Image.new("L", mask.size, 0)
    for dx in range(-r, r + 1):
        for dy in range(-r, r + 1):
            out.paste(255, (dx, dy), mask)
    return out


def caption(s, max_w):
    """Two-tone chunky caption with outline + drop shadow, word-wrapped to max_w."""
    words = s.split()
    # balanced split in two lines (or one line if it fits), biggest scale that fits
    options = [[s]] + [[" ".join(words[:i]), " ".join(words[i:])] for i in range(1, len(words))]
    for k in (14, 13, 12, 11, 10, 9, 8):
        fits = [o for o in options if all(text_mask(l, k).width <= max_w for l in o)]
        if fits:
            lines = min(fits, key=lambda o: (len(o) > 1 and max(text_mask(l, k).width for l in o) > max_w * 0.0, max(text_mask(l, k).width for l in o) - min(text_mask(l, k).width for l in o)))
            break
    o = k // 2 + 2
    imgs = []
    for line in lines:
        m = text_mask(line, k)
        pad = o + k
        big = Image.new("L", (m.width + pad * 2, m.height + pad * 2), 0)
        big.paste(m, (pad, pad))
        ring = dilate(big, o)
        tile = Image.new("RGBA", big.size, (0, 0, 0, 0))
        shadow = Image.new("RGBA", big.size, OUT + (255,))
        tile.paste(shadow, (0, k), ring)
        tile.paste(Image.new("RGBA", big.size, OUT + (255,)), (0, 0), ring)
        fill = Image.new("RGBA", big.size, (0, 0, 0, 0))
        fd = ImageDraw.Draw(fill)
        split = pad + int(m.height * 0.58)
        fd.rectangle((0, 0, big.width, split), fill=(255, 255, 255, 255))
        fd.rectangle((0, split, big.width, big.height), fill=(255, 214, 72, 255))
        tile.paste(fill, (0, 0), big)
        imgs.append(tile)
    return imgs


def gradient(top, bot):
    g = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(g)
    for y in range(H):
        t = y / (H - 1)
        d.line((0, y, W, y), fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return g


def build(raw, lang, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for i, (name, top, bot, caps) in enumerate(SHOTS):
        bg = gradient(top, bot).convert("RGBA")
        # game frame: 180x320 x4.5 = 810x1440, framed, bottom aligned
        FW, FH = 810, 1440
        fr = Image.open(os.path.join(raw, name + ".png")).convert("RGBA").resize((FW, FH), Image.NEAREST)
        fx, fy = (W - FW) // 2, H - FH - 44
        d = ImageDraw.Draw(bg)
        d.rounded_rectangle((fx - 14, fy - 14, fx + FW + 13, fy + FH + 13), radius=34, fill=OUT + (255,))
        d.rounded_rectangle((fx - 6, fy - 6, fx + FW + 5, fy + FH + 5), radius=26, fill=(255, 255, 255, 255))
        mask = Image.new("L", (FW, FH), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, FW - 1, FH - 1), radius=22, fill=255)
        bg.paste(fr, (fx, fy), mask)
        lines = caption(caps[lang], W - 80)
        total = sum(l.height for l in lines) - 10 * (len(lines) - 1)
        y = max(10, (fy - 14 - total) // 2)
        for l in lines:
            bg.alpha_composite(l, ((W - l.width) // 2, y))
            y += l.height - 10
        path = os.path.join(out_dir, "%d_%s.png" % (i + 1, name.split("_", 1)[1] if name.startswith("u") else ["play", "night", "planets", "coins"][int(name[1]) - 1]))
        bg.convert("RGB").save(path, optimize=True)
        print(path)


if __name__ == "__main__":
    build(sys.argv[1], sys.argv[2], sys.argv[3])
