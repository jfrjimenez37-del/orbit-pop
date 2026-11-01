#!/usr/bin/env python3
"""Captions for the epic promo video (tests/promo_epic.gd): chunky two-tone pixel text with an
outline and a drop shadow, same look as the store screenshots, one PNG per caption.
    python3 tools/gen_video_caps.py <out_dir>
Pixel size k is a multiple of 6 px (= 1 game pixel at 1080x1920) so the text stays crisp."""
import os, sys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
from gen_store_shots import text_mask, dilate, OUT

# id: (lines, pixel size, top colour, bottom colour)
WHITE, GOLD, PINK, CYAN, RED = (255, 255, 255), (255, 214, 72), (255, 150, 200), (150, 230, 255), (255, 90, 90)
CAPS = {
    "one_tap": (["ONE TAP"], 24, WHITE, GOLD),
    "to_flip": (["TO FLIP"], 24, WHITE, GOLD),
    "flip": (["FLIP!"], 30, WHITE, GOLD),
    "dodge": (["DODGE!"], 30, WHITE, PINK),
    "jump": (["JUMP!"], 30, WHITE, CYAN),
    "repeat": (["REPEAT!"], 24, WHITE, GOLD),
    "too_close": (["TOO CLOSE?"], 18, WHITE, RED),
    "jump_planets": (["JUMP", "PLANETS"], 18, WHITE, CYAN),
    "dodge_all": (["DODGE", "EVERYTHING"], 18, WHITE, PINK),
    "four": (["UP TO 4", "PLANETS"], 18, WHITE, GOLD),
    "move": (["THAT", "MOVE!"], 24, WHITE, CYAN),
    "worlds": (["16 WORLDS"], 18, WHITE, GOLD),
    "clouds": (["FROM THE", "CLOUDS..."], 18, WHITE, CYAN),
    "space": (["...TO DEEP", "SPACE!"], 18, WHITE, PINK),
    "how_high": (["HOW HIGH", "CAN YOU GO?"], 18, WHITE, GOLD),
    "dare": (["YOUR FRIEND", "DARES YOU..."], 12, WHITE, PINK),
    "beat": (["BEAT THEIR", "SCORE!"], 18, WHITE, GOLD),
    "win": (["YOU WIN!"], 24, WHITE, GOLD),
    "skins": (["29 SKINS"], 18, WHITE, PINK),
    "trails": (["22 TRAILS"], 18, WHITE, CYAN),
    "survive": (["CAN YOU", "SURVIVE?"], 18, WHITE, RED),
    "free": (["PLAY FREE"], 18, WHITE, GOLD),
    "gplay": (["ON GOOGLE PLAY"], 12, WHITE, CYAN),
}


def line_img(text, k, top, bot):
    m = text_mask(text, k)
    o = k // 2 + 2
    pad = o + k
    big = Image.new("L", (m.width + pad * 2, m.height + pad * 2), 0)
    big.paste(m, (pad, pad))
    ring = dilate(big, o)
    tile = Image.new("RGBA", big.size, (0, 0, 0, 0))
    tile.paste(Image.new("RGBA", big.size, OUT + (255,)), (0, k), ring)
    tile.paste(Image.new("RGBA", big.size, OUT + (255,)), (0, 0), ring)
    fill = Image.new("RGBA", big.size, (0, 0, 0, 0))
    fd = ImageDraw.Draw(fill)
    split = pad + int(m.height * 0.58)
    fd.rectangle((0, 0, big.width, split), fill=top + (255,))
    fd.rectangle((0, split, big.width, big.height), fill=bot + (255,))
    tile.paste(fill, (0, 0), big)
    return tile


def build(out):
    os.makedirs(out, exist_ok=True)
    for cid, (lines, k, top, bot) in CAPS.items():
        while True:   # shrink by whole game pixels until it fits the 1080 px frame
            imgs = [line_img(l, k, top, bot) for l in lines]
            if max(i.width for i in imgs) <= 1040 or k <= 6:
                break
            k -= 6
        gap = k + 2
        w = max(i.width for i in imgs)
        h = sum(i.height for i in imgs) - gap * (len(imgs) - 1)
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        y = 0
        for i in imgs:
            im.alpha_composite(i, ((w - i.width) // 2, y))
            y += i.height - gap
        im.save(os.path.join(out, cid + ".png"))
        print(cid, im.size)


if __name__ == "__main__":
    build(sys.argv[1])
