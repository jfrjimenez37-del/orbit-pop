#!/usr/bin/env python3
"""Builds the Play Console "Import achievements" zip (store/achievements_import.zip):
AchievementsMetadata.csv + AchievementsIconsMappings.csv + one 512x512 pixel-art icon each.
Format: https://developer.android.com/games/pgs/integrate-achievements (no header rows).
Run from the project root:  python3 tools/gen_achievements.py [--skip "Primer vuelo"]
"""
import io, os, sys, zipfile
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..")
SPR = os.path.join(ROOT, "assets", "sprites")
OUT = os.path.join(ROOT, "store", "achievements_import.zip")

# (game id, Play Console name, description, points, icon sprite, tier 0..4)
# Names must match progress.gd ids one-to-one; the game maps Play ids by these names.
ACH = [
    ("first", "Primer vuelo", "Juega tu primera partida", 5, "char_poppy", 0),
    ("score25", "25 puntos", "Consigue 25 puntos en una partida", 5, "icon_star", 0),
    ("score50", "50 puntos", "Consigue 50 puntos en una partida", 10, "icon_star", 0),
    ("score100", "100 puntos", "Consigue 100 puntos en una partida", 15, "icon_star", 1),
    ("score200", "200 puntos", "Consigue 200 puntos en una partida", 25, "icon_star", 1),
    ("score350", "350 puntos", "Consigue 350 puntos en una partida", 35, "icon_star", 2),
    ("score500", "500 puntos", "Consigue 500 puntos en una partida", 50, "icon_star", 3),
    ("score750", "750 puntos", "Consigue 750 puntos en una partida", 70, "icon_star", 3),
    ("score1000", "1000 puntos", "Consigue 1000 puntos en una partida", 100, "icon_star", 4),
    ("world3", "Mundo 3", "Llega al mundo 3", 10, "icon_world", 0),
    ("world5", "Mundo 5", "Llega al mundo 5", 15, "icon_world", 1),
    ("world7", "Mundo 7", "Llega al mundo 7", 25, "icon_world", 2),
    ("world10", "Mundo 10", "Llega al mundo 10", 50, "icon_world", 3),
    ("world15", "Mundo 15", "Llega al mundo 15", 75, "icon_world", 4),
    ("near100", "100 cercanas", "Esquiva 100 obstáculos por muy poco", 10, "icon_rush", 0),
    ("near500", "500 cercanas", "Esquiva 500 obstáculos por muy poco", 25, "icon_rush", 2),
    ("near2000", "2000 cercanas", "Esquiva 2000 obstáculos por muy poco", 50, "icon_rush", 3),
    ("bubbles250", "250 burbujas", "Revienta 250 burbujas", 15, "bubble", 1),
    ("bubbles1000", "1000 burbujas", "Revienta 1000 burbujas", 40, "bubble", 3),
    ("games100", "100 partidas", "Juega 100 partidas", 10, "icon_retry", 0),
    ("games500", "500 partidas", "Juega 500 partidas", 30, "icon_retry", 2),
    ("games1000", "1000 partidas", "Juega 1000 partidas", 60, "icon_retry", 3),
    ("total5000", "5000 puntos en total", "Suma 5000 puntos entre todas tus partidas", 10, "icon_trophy", 0),
    ("total25000", "25000 puntos en total", "Suma 25000 puntos entre todas tus partidas", 30, "icon_trophy", 2),
    ("total100000", "100000 puntos en total", "Suma 100000 puntos entre todas tus partidas", 60, "icon_trophy", 4),
    ("missions10", "10 misiones", "Completa 10 misiones diarias", 10, "icon_mission", 0),
    ("missions30", "30 misiones", "Completa 30 misiones diarias", 25, "icon_mission", 2),
    ("missions100", "100 misiones", "Completa 100 misiones diarias", 50, "icon_mission", 3),
    ("switch50", "50 cambios de órbita", "Cambia de órbita 50 veces en los cruces", 10, "icon_trail", 0),
    ("switch250", "250 cambios de órbita", "Cambia de órbita 250 veces en los cruces", 25, "icon_trail", 2),
    ("warp25", "25 teletransportes", "Usa el teletransporte 25 veces", 15, "icon_teleport", 1),
    ("skins10", "10 skins", "Desbloquea 10 skins", 10, "icon_skins", 1),
    ("skins20", "20 skins", "Desbloquea 20 skins", 15, "icon_skins", 2),
    ("skins_all", "Todas las skins", "Desbloquea las 26 skins", 10, "char_omega", 4),
]

# ring + background per tier: bronze, silver, gold, crystal, mythic
TIERS = [((214, 132, 66), (255, 214, 160), (96, 150, 255)),
         ((196, 206, 226), (250, 252, 255), (70, 120, 220)),
         ((255, 196, 40), (255, 244, 170), (255, 120, 90)),
         ((110, 220, 255), (226, 250, 255), (120, 80, 220)),
         ((255, 80, 160), (255, 200, 236), (40, 24, 80))]
OUTLINE = (38, 28, 66)


def icon(sprite: str, tier: int) -> Image.Image:
    ring, ring_hi, bg = TIERS[tier]
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for box, col in [((2, 2, 61, 61), OUTLINE), ((4, 4, 59, 59), ring), ((6, 6, 57, 57), ring_hi),
                     ((8, 8, 55, 55), ring), ((10, 10, 53, 53), OUTLINE)]:
        d.ellipse(box, fill=col)
    # medal face: vertical gradient clipped to a disc
    face = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    top = tuple(min(255, c + 60) for c in bg)
    fd = ImageDraw.Draw(face)
    for y in range(11, 53):
        t = (y - 11) / 42
        fd.line((0, y, 63, y), fill=tuple(int(top[i] * (1 - t) + bg[i] * t) for i in range(3)))
    mask = Image.new("L", (64, 64), 0)
    ImageDraw.Draw(mask).ellipse((11, 11, 52, 52), fill=255)
    im.paste(face, (0, 0), mask)
    for p in [(20, 16), (21, 16), (17, 20), (17, 21)]:   # shine
        im.putpixel(p, (255, 255, 255, 200))
    src = Image.open(os.path.join(SPR, sprite + ".png")).convert("RGBA")
    if sprite.startswith("char_"):
        src = src.crop((16, 0, 32, 16))      # idle frame of the sprite sheet
    k = max(1, min(32 // src.width, 32 // src.height))
    src = src.resize((src.width * k, src.height * k), Image.NEAREST)
    im.alpha_composite(src, ((64 - src.width) // 2, (64 - src.height) // 2 + 1))
    return im.resize((512, 512), Image.NEAREST)


def main() -> None:
    skip = set()
    if "--skip" in sys.argv:
        skip = set(sys.argv[sys.argv.index("--skip") + 1].split(";"))
    meta, maps = io.StringIO(), io.StringIO()
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        for order, (gid, name, desc, pts, spr, tier) in enumerate(ACH, 1):
            assert "," not in name and "," not in desc and pts % 5 == 0
            if name in skip:   # already created in Play Console: export its icon for manual upload
                icon(spr, tier).save(os.path.join(ROOT, "store", "ach_%s.png" % gid))
                continue
            meta.write("%s,%s,False,,Revealed,%d,%d\n" % (name, desc, pts, order))
            fn = "ach_%s.png" % gid
            maps.write("%s,%s\n" % (name, fn))
            buf = io.BytesIO()
            icon(spr, tier).save(buf, "PNG")
            z.writestr(fn, buf.getvalue())
        z.writestr("AchievementsMetadata.csv", meta.getvalue().encode("utf-8"))
        z.writestr("AchievementsIconsMappings.csv", maps.getvalue().encode("utf-8"))
    print("total points:", sum(a[3] for a in ACH), "->", OUT)


if __name__ == "__main__":
    main()
