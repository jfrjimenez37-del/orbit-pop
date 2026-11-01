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

## Epic video (`store/promo_epic.mp4`)

33 s, 1080×1920, **60 fps**, music **"Spin Bonk Repeat"** (made by the developer with Gemini) plus
the game's sounds. Cut to the beat (120 BPM): close-up hook (ONE TAP / TO FLIP) → the drop
(FLIP! DODGE! JUMP! REPEAT!) → slow motion with a real near miss (TOO CLOSE?) → a world per bar
(JUMP PLANETS · DODGE EVERYTHING · UP TO 4 PLANETS · THAT MOVE!) → the climb, a world every two
beats (16 WORLDS · FROM THE CLOUDS... · ...TO DEEP SPACE! · HOW HIGH CAN YOU GO?) → a duel
(YOUR FRIEND DARES YOU... · BEAT THEIR SCORE! · YOU WIN!) → 29 SKINS · 22 TRAILS → CAN YOU
SURVIVE? → logo, PLAY FREE ON GOOGLE PLAY. Best for YouTube Shorts / TikTok / Reels and as the
Play Store video.

    python3 tools/gen_video_caps.py /tmp/epic/caps
    (override.cfg as above)
    xvfb-run -a -s "-screen 0 1200x2000x24" godot47 --path . --write-movie /tmp/epic/f/f.png \
        --fixed-fps 60 --script tests/promo_epic.gd -- /tmp/epic/caps
    rm override.cfg
    ffmpeg -framerate 60 -i /tmp/epic/f/f%08d.png -i Spin_Bonk_Repeat.mp3 -i /tmp/epic/f/f.wav \
        -filter_complex "[1:a]atrim=0:33,asetpts=PTS-STARTPTS,volume=-1.5dB,afade=t=out:st=31.2:d=1.8[m];[2:a]atrim=0:33,asetpts=PTS-STARTPTS,volume=-7dB[s];[m][s]amix=inputs=2:normalize=0,alimiter=limit=0.95[a]" \
        -map 0:v -map "[a]" -t 33 -c:v libx264 -preset slow -tune animation -crf 14 -pix_fmt yuv420p \
        -c:a aac -b:a 256k -movflags +faststart store/promo_epic.mp4

Title: **ORBIT POP – One tap. 16 worlds. Can you survive?** (same description and hashtags).

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
