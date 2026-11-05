# Commercial with actors (Google Flow) + the real game

`OrbitPop_ad_15s_en.mp4` / `_es.mp4`: 15 s, 1080x1920, 30 fps, about -16 LUFS.

| Time | Shot |
|---|---|
| 0-2 | Flow S01: "No way!" (caption NO WAY! / ¡NO PUEDE SER!) |
| 2-4.5 | Game: near miss in slow motion (world 11, 4 planets) |
| 4.5-6.5 | Flow S02: "My turn!" (caption MY TURN! / ¡ME TOCA!) |
| 6.5-9.5 | Flow S03 green-screen phone with the real duel inside (corners tracked per frame) |
| 9.5-10.8 | Game: overtaking MAYA, "YOU'RE AHEAD!" |
| 10.8-12.5 | Game: the real duel result, YOU WIN! +50 |
| 12.5-15 | Flow end card (character on a planet) + game logo + PLAY FREE / JUEGA GRATIS |

The phone insert uses footage rendered at the phone screen's own shape (1080x2220, the game's
tall-screen layout), so nothing is stretched or padded inside the screen.

The actors speak English in both versions; the Spanish one has Spanish captions (no dubbing over
English lips). Music: `assets/music/planets.ogg`, ducked under the voices.

Rebuild (Flow takes are not in the repository):

    # game footage (18.5 s, see _tl_ad in tests/promo_epic.gd), per language
    printf '[display]\n\nwindow/size/window_width_override=1080\nwindow/size/window_height_override=1920\nwindow/stretch/mode="canvas_items"\n' > override.cfg
    xvfb-run -a -s "-screen 0 1200x2000x24" godot47 --path . --write-movie /tmp/f/f.png --fixed-fps 60 \
        --script tests/promo_epic.gd -- /tmp/caps ad en
    rm override.cfg
    ffmpeg -framerate 60 -i /tmp/f/f%08d.png -i /tmp/f/f.wav -c:v libx264 -crf 14 -pix_fmt yuv420p -c:a pcm_s16le game_en.mov
    # the same at 1080x2220 for the phone screen: frames 180-479 (game 3-8 s) -> phone_en.mov
    python3 tools/make_ad.py <takes_dir> game_en.mov <end_card.mp4> assets/music/planets.ogg en out.mp4 phone_en.mov
    ffmpeg -i out.mp4 -c:v copy -af loudnorm=I=-14:TP=-1.5:LRA=11 -c:a aac -b:a 192k store/ad/OrbitPop_ad_15s_en.mp4
