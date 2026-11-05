#!/usr/bin/env python3
"""Live-action commercial: actors from Google Flow + the real game (tests/promo_epic.gd "ad").

    python3 tools/make_ad.py <takes_dir> <game.mov> <end_card.mp4> <music> <lang> <out.mp4> [phone.mov]

takes_dir holds OrbitPop_S01_Reaction_EN_v1.mp4, OrbitPop_S02_MyTurn_EN_v1.mp4 and
OrbitPop_S03_GreenScreen_v1.mp4 (720x1280). game.mov is the 18.5 s render of the "ad" variant:
A 0-3 near miss · B 3-7 duel · C 7-10 overtaking · D 10-12.5 duel result · E 12.5-15.5 moving
planets · F 15.5-18.5 logo (the 15 s cut uses A, B, C, D). The game goes into the green phone screen frame by frame (corners
found from the green, the notch and bezel stay on top). Output 1080x1920, 30 fps.
"""
import os, subprocess, sys, tempfile
import numpy as np
from PIL import Image, ImageFilter
sys.path.insert(0, os.path.dirname(__file__))
from gen_video_caps import line_img, WHITE, GOLD, PINK, CYAN

W, H, FPS = 1080, 1920, 30
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (source, from, to)  -- actor takes by short name, game segments from the game render
CUTS = [
    ("S01", 0.6, 2.6),      # "No way!" (speech 1.4-2.3 s)
    ("game", 0.0, 2.5),     # near miss in slow motion
    ("S02", 0.9, 2.9),      # "My turn!" (speech 1.4-2.5 s)
    ("S03", 0.4, 3.4),      # the duel on the phone (GREEN_GAME inside the green screen)
    ("game", 8.6, 9.9),     # overtaking the friend's score: YOU'RE AHEAD!
    ("game", 10.2, 11.9),   # the real duel result
    ("end", 0.0, 2.5),      # end card + logo
]
TAKES = {"S01": "OrbitPop_S01_Reaction_EN_v1.mp4", "S02": "OrbitPop_S02_MyTurn_EN_v1.mp4",
         "S03": "OrbitPop_S03_GreenScreen_v1.mp4"}
GREEN_GAME = (4.0, 7.0)
# caption per cut index: (lines, pixel size, top, bottom colour, y centre, from, to (cut time))
CAPS = {
    "en": {0: (["NO WAY!"], 18, WHITE, GOLD, 1520, 0.75, 9), 2: (["MY TURN!"], 18, WHITE, CYAN, 1520, 0.45, 9),
           6: (["PLAY FREE"], 24, WHITE, GOLD, 680, 0.4, 9)},
    "es": {0: (["¡NO PUEDE SER!"], 18, WHITE, GOLD, 1520, 0.75, 9), 2: (["¡ME TOCA!"], 18, WHITE, CYAN, 1520, 0.45, 9),
           6: (["JUEGA GRATIS"], 24, WHITE, GOLD, 680, 0.4, 9)},
}
DUCK = 0.16    # music under the actors' voices
BED = 0.40     # music under the game


def run(cmd):
    subprocess.run(cmd, check=True)


def caption_png(lines, k, top, bot, path):
    while True:
        imgs = [line_img(l, k, top, bot) for l in lines]
        if max(i.width for i in imgs) <= 1000 or k <= 6:
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
    im.save(path)
    return im.size


def frames(src, t0, t1, out_dir, scale=True):
    os.makedirs(out_dir, exist_ok=True)
    vf = "fps=%d" % FPS + (",scale=%d:%d:flags=lanczos" % (W, H) if scale else "")
    run(["ffmpeg", "-v", "error", "-y", "-ss", "%.3f" % t0, "-t", "%.3f" % (t1 - t0), "-i", src, "-vf", vf,
         os.path.join(out_dir, "%04d.png")])
    return sorted(os.path.join(out_dir, f) for f in os.listdir(out_dir))


def coeffs(dst, src):
    """PIL perspective coefficients mapping output points dst -> input points src."""
    a = []
    for (x, y), (u, v) in zip(dst, src):
        a.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        a.append([0, 0, 0, x, y, 1, -v * x, -v * y])
    b = np.array(src, dtype=float).reshape(8)
    return np.linalg.solve(np.array(a, dtype=float), b).tolist()


def green_composite(phone_frames, game_frames, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    quads = []
    masks = []
    for f in phone_frames:
        a = np.asarray(Image.open(f).convert("RGB")).astype(int)
        r, g, b = a[..., 0], a[..., 1], a[..., 2]
        m = (g > 90) & (g - np.maximum(r, b) > 40)
        ys, xs = np.nonzero(m)
        s, d = xs + ys, xs - ys
        q = np.array([[xs[s.argmin()], ys[s.argmin()]], [xs[d.argmax()], ys[d.argmax()]],
                      [xs[s.argmax()], ys[s.argmax()]], [xs[d.argmin()], ys[d.argmin()]]], dtype=float)
        quads.append(q)
        masks.append(m)
    quads = np.array(quads)
    n = len(phone_frames)
    for i in range(n):
        q = quads[max(0, i - 2):i + 3].mean(axis=0)          # steady corners
        c = q.mean(axis=0)
        q = c + (q - c) * 1.03                                # past the rounded corners
        qw = (np.linalg.norm(q[1] - q[0]) + np.linalg.norm(q[2] - q[3])) / 2
        qh = (np.linalg.norm(q[3] - q[0]) + np.linalg.norm(q[2] - q[1])) / 2
        game = np.asarray(Image.open(game_frames[min(i, len(game_frames) - 1)]).convert("RGB"))
        gh = int(round(game.shape[1] * qh / qw))              # the screen is taller than 9:16
        pad = max(0, (gh - game.shape[0]) // 2)
        # the screen is taller than the game: fill the strips with the flat average colour of the
        # game's top / bottom band (stretching the edge row turns moving clouds into white bars)
        top = game[:40].reshape(-1, 3).mean(axis=0)
        bot = game[-40:].reshape(-1, 3).mean(axis=0)
        game = np.concatenate([np.tile(top, (pad, game.shape[1], 1)), game,
                               np.tile(bot, (pad, game.shape[1], 1))]).astype(np.uint8)
        gi = Image.fromarray(game)
        src = [(0, 0), (gi.width, 0), (gi.width, gi.height), (0, gi.height)]
        warped = gi.transform((W, H), Image.PERSPECTIVE, coeffs([tuple(p) for p in q], src), Image.BICUBIC)
        mask = Image.fromarray((masks[i] * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(1.2))
        frame = Image.open(phone_frames[i]).convert("RGB")
        frame.paste(warped, (0, 0), mask)
        frame.save(os.path.join(out_dir, "%04d.png" % (i + 1)))
    return sorted(os.path.join(out_dir, f) for f in os.listdir(out_dir))


def main():
    takes, game, end_card, music, lang, out = sys.argv[1:7]
    # optional: the same footage rendered at the phone's screen shape (1080x2220) from game time
    # 3.0 s, so the game fills the green screen without any padding
    phone = sys.argv[7] if len(sys.argv) > 7 else ""
    tmp = tempfile.mkdtemp(prefix="ad_", dir=os.path.dirname(os.path.abspath(out)))
    caps = CAPS[lang]
    seg_files = []
    starts = []
    t = 0.0
    for idx, (src, a, b) in enumerate(CUTS):
        starts.append(t)
        seg = os.path.join(tmp, "seg%02d.mp4" % idx)
        d = b - a
        if src == "S03":
            ph = frames(os.path.join(takes, TAKES["S03"]), a, b, os.path.join(tmp, "ph"))
            if phone:
                gm = frames(phone, GREEN_GAME[0] - 3.0, GREEN_GAME[1] - 3.0, os.path.join(tmp, "gm"), scale=False)
            else:
                gm = frames(game, GREEN_GAME[0], GREEN_GAME[1], os.path.join(tmp, "gm"), scale=False)
            comp = green_composite(ph, gm, os.path.join(tmp, "comp"))
            run(["ffmpeg", "-v", "error", "-y", "-framerate", str(FPS), "-i", os.path.join(tmp, "comp", "%04d.png"),
                 "-t", "%.3f" % d, "-c:v", "libx264", "-crf", "15", "-preset", "medium", "-pix_fmt", "yuv420p", seg])
        else:
            path = game if src == "game" else (end_card if src == "end" else os.path.join(takes, TAKES[src]))
            inputs = ["-ss", "%.3f" % a, "-t", "%.3f" % d, "-i", path]
            chain = "[0:v]fps=%d,scale=%d:%d:flags=lanczos,setsar=1,format=rgba[v0]" % (FPS, W, H)
            last = "v0"
            n_in = 1
            if src == "end":
                logo = Image.open(os.path.join(ROOT, "assets/sprites/logo.png")).convert("RGBA")
                logo = logo.resize((logo.width * 6, logo.height * 6), Image.NEAREST)
                lp = os.path.join(tmp, "logo.png")
                logo.save(lp)
                inputs += ["-loop", "1", "-t", "%.3f" % d, "-i", lp]
                chain += ";[v0][1:v]overlay=x=(W-w)/2:y=60:enable='gte(t,0.15)'[v1]"
                last = "v1"
                n_in = 2
            if idx in caps:
                lines, k, top, bot, yc, c0, c1 = caps[idx]
                cp = os.path.join(tmp, "cap%02d.png" % idx)
                cw, ch = caption_png(lines, k, top, bot, cp)
                inputs += ["-loop", "1", "-t", "%.3f" % d, "-i", cp]
                chain += ";[%s][%d:v]overlay=x=(W-w)/2:y=%d:enable='between(t,%.2f,%.2f)'[vc]" % (last, n_in, yc - ch // 2, c0, min(c1, d))
                last = "vc"
            chain += ";[%s]format=yuv420p[vo]" % last
            run(["ffmpeg", "-v", "error", "-y"] + inputs + ["-filter_complex", chain, "-map", "[vo]", "-t", "%.3f" % d,
                 "-r", str(FPS), "-c:v", "libx264", "-crf", "15", "-preset", "medium", seg])
        seg_files.append(seg)
        t += d
    total = t
    lst = os.path.join(tmp, "list.txt")
    with open(lst, "w") as f:
        for s in seg_files:
            f.write("file '%s'\n" % s)
    video = os.path.join(tmp, "video.mp4")
    run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", video])
    # audio: actors' voices, the game's sounds (quieter while on the phone), music ducked under voices
    ins = ["-i", video]
    parts = []
    voice_win = []
    n = 1
    for idx, (src, a, b) in enumerate(CUTS):
        st = starts[idx]
        if src in ("S01", "S02"):
            ins += ["-ss", "%.3f" % a, "-t", "%.3f" % (b - a), "-i", os.path.join(takes, TAKES[src])]
            parts.append("[%d:a]adelay=%d:all=1,volume=1.6[a%d]" % (n, int(st * 1000), n))
            voice_win.append((st, st + b - a))
        elif src in ("game", "S03"):
            ga, gb = (GREEN_GAME if src == "S03" else (a, b))
            ins += ["-ss", "%.3f" % ga, "-t", "%.3f" % (gb - ga), "-i", game]
            vol = 0.45 if src == "S03" else 0.9
            parts.append("[%d:a]adelay=%d:all=1,volume=%.2f[a%d]" % (n, int(st * 1000), vol, n))
        else:
            continue
        n += 1
    ins += ["-ss", "14.0", "-t", "%.3f" % total, "-i", music]
    duck = "+".join("between(t,%.2f,%.2f)" % w for w in voice_win)
    parts.append("[%d:a]volume='if(%s,%.2f,%.2f)':eval=frame,afade=t=out:st=%.2f:d=1.2[m]" % (n, duck, DUCK, BED, total - 1.2))
    mix = "".join("[a%d]" % i for i in range(1, n)) + "[m]"
    parts.append("%samix=inputs=%d:normalize=0:duration=longest,alimiter=limit=0.95,atrim=0:%.3f[aout]" % (mix, n, total))
    run(["ffmpeg", "-v", "error", "-y"] + ins + ["-filter_complex", ";".join(parts), "-map", "0:v", "-map", "[aout]",
         "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-t", "%.3f" % total, out])
    subprocess.run(["rm", "-rf", tmp])
    print(out, "%.1f s" % total)


if __name__ == "__main__":
    main()
