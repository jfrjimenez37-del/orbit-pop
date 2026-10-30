# Promo videos — ORBIT POP

Three short portrait videos (1080×1920, ~15 s, the game's own music and sounds), rendered at full
resolution by `tests/promo_videos.gd` (a showcase bot plays: it dodges and jumps planet at the
crossings; worlds are jumped to so each video shows its idea fast):

| File | Idea | Captions |
|---|---|---|
| `store/promo_planets.mp4` | jumping between planets, 4 planets, moving planets | TAP TO JUMP PLANETS! · FLIP. DODGE. JUMP! · 4 PLANETS... · ...THAT MOVE! · PLAY FREE NOW! |
| `store/promo_climb.mp4` | the climb from the clouds to deep space (altitude layers) | HOW HIGH CAN YOU ORBIT? · FROM THE CLOUDS... · THROUGH THE SKY... · TO THE EDGE OF SPACE! · THE MOON... · AND BEYOND! · FREE ON GOOGLE PLAY |
| `store/promo_duel.mp4` | a friend's duel, the win, the daily challenge | YOUR FRIEND DARES YOU... · BEAT THEIR SCORE! · WIN AND SEND IT BACK! · NEW CHALLENGE EVERY DAY · PLAY FREE NOW! |

Suggested use: **planets** as the Play Store video (it shows the core game), **climb** and
**duel** for YouTube Shorts / TikTok / Instagram Reels and ads.

Google Play only takes a **YouTube link** (Play Console > Store presence > Main store listing >
Video): upload as **Public** or **Unlisted** (not Private), not "made for kids", no age
restriction, and paste the URL.

## Re-render

The game draws a 180×320 canvas; for the video it is drawn at 6x (canvas_items stretch) through a
temporary `override.cfg` that must be deleted right after (it is in `.git/info/exclude`):

    printf '[display]\n\nwindow/size/window_width_override=1080\nwindow/size/window_height_override=1920\nwindow/stretch/mode="canvas_items"\n' > override.cfg
    xvfb-run -a -s "-screen 0 1200x2000x24" godot47 --path . --write-movie /tmp/v.avi --fixed-fps 30 \
        --script tests/promo_videos.gd -- planets      # or climb / duel
    rm override.cfg
    ffmpeg -i /tmp/v.avi -c:v libx264 -preset slow -tune animation -crf 14 -pix_fmt yuv420p \
        -c:a aac -b:a 192k -movflags +faststart store/promo_planets.mp4

## YouTube texts

**Titles:**
- ORBIT POP – Tap to jump planets! (one-tap arcade)
- ORBIT POP – How high can you orbit?
- ORBIT POP – Beat your friends on the same run

**Description (all three):**
One tap to flip your orbit! Dodge meteors, jump between planets, duel your friends on the
same run and beat the daily challenge. 16 worlds, from the clouds to deep space.
Free on Google Play: https://play.google.com/store/apps/details?id=com.barriogames.orbitpop

#arcade #indiegame #pixelart #mobilegame #android #shorts
