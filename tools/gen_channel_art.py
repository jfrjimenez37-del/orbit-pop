#!/usr/bin/env python3
"""Channel art for YouTube / TikTok / Instagram:
  store/social/youtube_banner_2560x1440.png  (logo + tagline inside the 1546x423 safe area that
      every device shows; two phones with gameplay outside it, seen on TV / desktop)
  store/social/profile_800.png               (the app icon, for a round crop)
Stills: clean 1080x1920 frames from tests/promo_epic.gd (variant "stills").
    python3 tools/gen_channel_art.py /tmp/epic/stills
"""
import os, sys, random
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
from gen_video_caps import line_img, WHITE, GOLD, CYAN
from gen_store_shots import OUT

ROOT = os.path.join(os.path.dirname(__file__), "..")
W, H = 2560, 1440


def phone(still, h, angle):
    fw, fh = int(h * 9 / 16), h
    fr = Image.open(still).convert("RGBA").resize((fw, fh), Image.LANCZOS)
    pad = 18
    ph = Image.new("RGBA", (fw + pad * 2, fh + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(ph)
    d.rounded_rectangle((0, 0, ph.width - 1, ph.height - 1), radius=56, fill=OUT + (255,))
    d.rounded_rectangle((7, 7, ph.width - 8, ph.height - 8), radius=50, fill=(255, 255, 255, 255))
    m = Image.new("L", (fw, fh), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, fw - 1, fh - 1), radius=40, fill=255)
    ph.paste(fr, (pad, pad), m)
    return ph.rotate(angle, resample=Image.BICUBIC, expand=True)


def banner(stills):
    bg = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(bg)
    top, bot = (16, 14, 48), (92, 48, 140)
    for y in range(H):
        t = y / (H - 1)
        d.line((0, y, W, y), fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,))
    rnd = random.Random(7)
    for _ in range(260):   # pixel stars (6 px = one game pixel)
        x, y = rnd.randrange(0, W // 6) * 6, rnd.randrange(0, H // 6) * 6
        c = rnd.choice([(255, 255, 255), (255, 236, 140), (170, 220, 255)])
        s = 6 if rnd.random() < 0.8 else 12
        d.rectangle((x, y, x + s - 1, y + s - 1), fill=c + (rnd.randrange(120, 256),))
    left = phone(os.path.join(stills, "2.png"), 940, 8)
    right = phone(os.path.join(stills, "1.png"), 940, -8)
    bg.alpha_composite(left, (280 - left.width // 2, H // 2 - left.height // 2))
    bg.alpha_composite(right, (W - 280 - right.width // 2, H // 2 - right.height // 2))
    logo = Image.open(os.path.join(ROOT, "assets/sprites/logo.png")).convert("RGBA")
    logo = logo.resize((logo.width * 4, logo.height * 4), Image.NEAREST)
    l1 = line_img("ONE TAP.", 10, WHITE, GOLD)
    l2 = line_img("FLIP YOUR ORBIT!", 8, WHITE, CYAN)
    l3 = line_img("FREE ON GOOGLE PLAY", 5, WHITE, GOLD)
    tw = max(l1.width, l2.width, l3.width)
    gap = 40
    x0 = (W - (logo.width + gap + tw)) // 2
    bg.alpha_composite(logo, (x0, H // 2 - logo.height // 2))
    th = l1.height + l2.height + l3.height - 40
    y = H // 2 - th // 2
    tx = x0 + logo.width + gap
    for l in (l1, l2, l3):
        bg.alpha_composite(l, (tx + (tw - l.width) // 2, y))
        y += l.height - 20
    assert x0 >= 507 and tx + tw <= 2053, (x0, tx + tw)   # inside the safe area
    return bg.convert("RGB")


def profile():
    a = Image.open(os.path.join(ROOT, "assets/icon/icon_bg_432.png")).convert("RGBA")
    a.alpha_composite(Image.open(os.path.join(ROOT, "assets/icon/icon_fg_432.png")).convert("RGBA"))
    a = a.resize((864, 864), Image.NEAREST).crop((32, 32, 832, 832))
    return a.convert("RGB")


if __name__ == "__main__":
    out = os.path.join(ROOT, "store/social")
    os.makedirs(out, exist_ok=True)
    banner(sys.argv[1]).save(os.path.join(out, "youtube_banner_2560x1440.png"), optimize=True)
    profile().save(os.path.join(out, "profile_800.png"), optimize=True)
    print("ok")
