# Commercial with actors (Google Flow) + the real game

`OrbitPop_ad_duel_en.mp4` / `_es.mp4`: 25 s, 1080x1920, 30 fps, -16 LUFS.

| Time | Shot |
|---|---|
| 0-2.3 | Flow S01: "No way!" (caption NO WAY! / ¡NO PUEDE SER!) |
| 2.3-5.3 | Game: near miss in slow motion (world 11, 4 planets) |
| 5.3-7.4 | Flow S02: "My turn!" (caption MY TURN! / ¡ME TOCA!) |
| 7.4-11.4 | Flow S03 green-screen phone with the real duel inside (corners tracked per frame) |
| 11.4-14.4 | Game: overtaking MAYA, "YOU'RE AHEAD!" |
| 14.4-16.9 | Game: the real duel result, YOU WIN! +50 |
| 16.9-18.7 | Flow S02: silent laugh |
| 18.7-21.7 | Game: moving planets with pulsar beams (CAN YOU BEAT THIS SCORE?) |
| 21.7-25 | Flow end card (character on a planet) + game logo + PLAY FREE / JUEGA GRATIS |

The actors speak English in both versions; the Spanish one has Spanish captions (no dubbing over
English lips). Music: `assets/music/planets.ogg`, ducked under the voices.

Rebuild (Flow takes are not in the repository):

    # game footage (18.5 s, see _tl_ad in tests/promo_epic.gd), per language
    printf '[display]\n\nwindow/size/window_width_override=1080\nwindow/size/window_height_override=1920\nwindow/stretch/mode="canvas_items"\n' > override.cfg
    xvfb-run -a -s "-screen 0 1200x2000x24" godot47 --path . --write-movie /tmp/f/f.png --fixed-fps 60 \
        --script tests/promo_epic.gd -- /tmp/caps ad en
    rm override.cfg
    ffmpeg -framerate 60 -i /tmp/f/f%08d.png -i /tmp/f/f.wav -c:v libx264 -crf 14 -pix_fmt yuv420p -c:a pcm_s16le game_en.mov
    python3 tools/make_ad.py <takes_dir> game_en.mov <end_card.mp4> assets/music/planets.ogg en out.mp4
    ffmpeg -i out.mp4 -c:v copy -af loudnorm=I=-14:TP=-1.5:LRA=11 -c:a aac -b:a 192k store/ad/OrbitPop_ad_duel_en.mp4
