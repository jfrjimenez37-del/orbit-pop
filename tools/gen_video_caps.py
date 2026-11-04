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
    # social shorts
    "can_beat": (["CAN YOU BEAT", "MY SCORE?"], 18, WHITE, GOLD),
    "same_run": (["SAME OBSTACLES", "AS ME"], 12, WHITE, CYAN),
    "no_powers": (["NO POWER-UPS", "JUST SKILL"], 12, WHITE, PINK),
    "your_turn": (["YOUR TURN!"], 18, WHITE, GOLD),
    "code": (["DUEL CODE IN", "THE COMMENTS!"], 12, WHITE, GOLD),
    "wait": (["WAIT FOR IT..."], 12, WHITE, CYAN),
    "reach16": (["CAN YOU REACH", "WORLD 16?"], 18, WHITE, GOLD),
    "how_far": (["HOW FAR", "CAN YOU GO?"], 18, WHITE, GOLD),
    "pick": (["PICK YOUR", "FAVORITE!"], 18, WHITE, PINK),
    "comment_fav": (["COMMENT YOUR", "FAVORITE!"], 18, WHITE, GOLD),
    "almost": (["ALMOST A", "NEW RECORD..."], 12, WHITE, GOLD),
    "nooo": (["NOOOO!"], 24, WHITE, RED),
    "one_more": (["ONE MORE", "TRY?"], 18, WHITE, GOLD),
    "one_more_1": (["ONE MORE TRY?"], 12, WHITE, GOLD),
}
# captions of the newer shorts (solo, button, levels, jumps, moving, daily)
CAPS.update({
    "solo1": (["I MADE THIS", "GAME ALONE"], 18, WHITE, GOLD),
    "solo2": (["IT HAS ONLY", "ONE BUTTON"], 18, WHITE, CYAN),
    "solo3": (["16 WORLDS", "29 SKINS"], 18, WHITE, PINK),
    "solo4": (["DUEL YOUR", "FRIENDS"], 18, WHITE, GOLD),
    "solo5": (["WOULD YOU", "PLAY IT?"], 18, WHITE, GOLD),
    "btn1": (["ONE BUTTON."], 18, WHITE, CYAN),
    "btn2": (["HOW HARD", "CAN IT BE?"], 18, WHITE, GOLD),
    "btn3": (["VERY."], 30, WHITE, RED),
    "btn4": (["16 WORLDS", "OF CHAOS"], 18, WHITE, PINK),
    "wn_1": (["WORLD 1"], 24, WHITE, CYAN),
    "wn_3": (["WORLD 3"], 24, WHITE, CYAN),
    "wn_6": (["WORLD 6"], 24, WHITE, GOLD),
    "wn_14": (["WORLD 14"], 24, WHITE, PINK),
    "wn_15": (["WORLD 15"], 24, WHITE, RED),
    "wn_16": (["WORLD 16"], 24, WHITE, RED),
    "stop": (["WHERE WOULD", "YOU STOP?"], 18, WHITE, GOLD),
    "sat1": (["SATISFYING", "PLANET JUMPS"], 18, WHITE, CYAN),
    "sat2": (["TAP AT THE", "CROSSING..."], 18, WHITE, GOLD),
    "sat3": (["...AND JUMP!"], 18, WHITE, PINK),
    "sat4": (["TRY IT", "YOURSELF"], 18, WHITE, GOLD),
    "mv1": (["3 PLANETS?", "EASY."], 18, WHITE, CYAN),
    "mv2": (["THEN THEY", "STARTED MOVING"], 12, WHITE, PINK),
    "mv3": (["WAIT, WHAT?!"], 18, WHITE, RED),
    "dl1": (["NEW CHALLENGE", "EVERY DAY"], 12, WHITE, GOLD),
    "dl2": (["SAME RUN", "FOR EVERYONE"], 18, WHITE, CYAN),
    "dl3": (["3 TRIES"], 24, WHITE, PINK),
    "dl4": (["TOP THE DAILY", "RANKING"], 12, WHITE, GOLD),
    "dl5": (["CAN YOU BE", "NUMBER 1?"], 18, WHITE, GOLD),
})

# Spanish versions (saved as <id>_es.png; ids without one fall back to English, e.g. skin names)
CAPS_ES = {
    "one_tap": (["UN TOQUE"], 24, WHITE, GOLD),
    "to_flip": (["PARA GIRAR"], 24, WHITE, GOLD),
    "flip": (["¡GIRA!"], 30, WHITE, GOLD),
    "dodge": (["¡ESQUIVA!"], 30, WHITE, PINK),
    "jump": (["¡SALTA!"], 30, WHITE, CYAN),
    "repeat": (["¡REPITE!"], 24, WHITE, GOLD),
    "too_close": (["¿MUY CERCA?"], 18, WHITE, RED),
    "jump_planets": (["SALTA ENTRE", "PLANETAS"], 18, WHITE, CYAN),
    "dodge_all": (["ESQUIVA", "TODO"], 18, WHITE, PINK),
    "four": (["HASTA 4", "PLANETAS"], 18, WHITE, GOLD),
    "move": (["¡Y SE", "MUEVEN!"], 24, WHITE, CYAN),
    "worlds": (["16 MUNDOS"], 18, WHITE, GOLD),
    "clouds": (["DESDE LAS", "NUBES..."], 18, WHITE, CYAN),
    "space": (["...HASTA EL", "ESPACIO"], 18, WHITE, PINK),
    "how_high": (["¿QUÉ TAN ALTO", "LLEGARÁS?"], 12, WHITE, GOLD),
    "dare": (["TU AMIGO", "TE RETA..."], 18, WHITE, PINK),
    "beat": (["¡SUPERA SU", "PUNTAJE!"], 18, WHITE, GOLD),
    "win": (["¡GANASTE!"], 24, WHITE, GOLD),
    "skins": (["29 SKINS"], 18, WHITE, PINK),
    "trails": (["22 ESTELAS"], 18, WHITE, CYAN),
    "survive": (["¿PUEDES", "SOBREVIVIR?"], 18, WHITE, RED),
    "free": (["JUEGA GRATIS"], 18, WHITE, GOLD),
    "gplay": (["EN GOOGLE PLAY"], 12, WHITE, CYAN),
    "can_beat": (["¿PUEDES", "SUPERAR MI", "PUNTAJE?"], 12, WHITE, GOLD),
    "same_run": (["LOS MISMOS", "OBSTÁCULOS"], 12, WHITE, CYAN),
    "no_powers": (["SIN PODERES,", "SOLO TALENTO"], 12, WHITE, PINK),
    "your_turn": (["¡TE TOCA!"], 18, WHITE, GOLD),
    "code": (["CÓDIGO DEL", "DUELO EN LOS", "COMENTARIOS"], 12, WHITE, GOLD),
    "wait": (["ESPERA..."], 18, WHITE, CYAN),
    "reach16": (["¿LLEGARÁS AL", "MUNDO 16?"], 12, WHITE, GOLD),
    "how_far": (["¿HASTA DÓNDE", "LLEGARÁS?"], 12, WHITE, GOLD),
    "pick": (["ELIGE TU", "FAVORITO"], 18, WHITE, PINK),
    "comment_fav": (["COMENTA TU", "FAVORITO"], 18, WHITE, GOLD),
    "almost": (["CASI UN", "NUEVO RÉCORD..."], 12, WHITE, GOLD),
    "nooo": (["¡NOOOO!"], 24, WHITE, RED),
    "one_more": (["¿OTRO", "INTENTO?"], 18, WHITE, GOLD),
    "one_more_1": (["¿OTRO INTENTO?"], 12, WHITE, GOLD),
    "solo1": (["HICE ESTE", "JUEGO SOLO"], 18, WHITE, GOLD),
    "solo2": (["TIENE UN", "SOLO BOTÓN"], 18, WHITE, CYAN),
    "solo3": (["16 MUNDOS", "29 SKINS"], 18, WHITE, PINK),
    "solo4": (["DUELOS CON", "AMIGOS"], 18, WHITE, GOLD),
    "solo5": (["¿LO", "JUGARÍAS?"], 18, WHITE, GOLD),
    "btn1": (["UN SOLO BOTÓN."], 12, WHITE, CYAN),
    "btn2": (["¿QUÉ TAN", "DIFÍCIL", "PUEDE SER?"], 18, WHITE, GOLD),
    "btn3": (["MUCHO."], 30, WHITE, RED),
    "btn4": (["16 MUNDOS", "DE CAOS"], 18, WHITE, PINK),
    "wn_1": (["MUNDO 1"], 24, WHITE, CYAN),
    "wn_3": (["MUNDO 3"], 24, WHITE, CYAN),
    "wn_6": (["MUNDO 6"], 24, WHITE, GOLD),
    "wn_14": (["MUNDO 14"], 24, WHITE, PINK),
    "wn_15": (["MUNDO 15"], 24, WHITE, RED),
    "wn_16": (["MUNDO 16"], 24, WHITE, RED),
    "stop": (["¿DÓNDE TE", "DETENDRÍAS?"], 18, WHITE, GOLD),
    "sat1": (["SALTOS ENTRE", "PLANETAS"], 18, WHITE, CYAN),
    "sat2": (["TOCA EN EL", "CRUCE..."], 18, WHITE, GOLD),
    "sat3": (["...¡Y SALTA!"], 18, WHITE, PINK),
    "sat4": (["PRUÉBALO", "TÚ MISMO"], 18, WHITE, GOLD),
    "mv1": (["¿3 PLANETAS?", "FÁCIL."], 18, WHITE, CYAN),
    "mv2": (["Y LUEGO", "EMPEZARON", "A MOVERSE"], 18, WHITE, PINK),
    "mv3": (["¿¡QUÉ!?"], 30, WHITE, RED),
    "dl1": (["UN RETO NUEVO", "CADA DÍA"], 12, WHITE, GOLD),
    "dl2": (["LA MISMA", "PARTIDA", "PARA TODOS"], 18, WHITE, CYAN),
    "dl3": (["3 INTENTOS"], 18, WHITE, PINK),
    "dl4": (["LIDERA EL", "RANKING DIARIO"], 12, WHITE, GOLD),
    "dl5": (["¿PUEDES SER", "EL NÚMERO 1?"], 12, WHITE, GOLD),
}

# skin names for the skins short (bottom colour = rarity)
RARITY = {"common": (190, 200, 220), "rare": CYAN, "epic": PINK, "legendary": GOLD, "mythic": RED}
for _id, _r in [("poppy", "common"), ("minty", "common"), ("berry", "common"), ("frosty", "rare"),
        ("ember", "rare"), ("volt", "rare"), ("ghosty", "epic"), ("alien", "epic"), ("crystal", "epic"),
        ("luna", "epic"), ("ninja", "epic"), ("neon", "epic"), ("magma", "legendary"),
        ("royal", "legendary"), ("prism", "legendary"), ("nova", "mythic")]:
    CAPS["sk_" + _id] = ([_id.upper()], 12, WHITE, RARITY[_r])


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
    every = list(CAPS.items()) + [(cid + "_es", v) for cid, v in CAPS_ES.items()]
    for cid, (lines, k, top, bot) in every:
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
