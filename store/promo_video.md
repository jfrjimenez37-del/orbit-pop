# Promo video — ORBIT POP

File: `store/promo_video.mp4` (portrait 1080×1920, ~27 s, the game's own music and sounds).
Recorded with Godot's movie maker from `tests/promo_video.gd` (a bot plays; worlds are jumped to
so many of them show). Re-record:

    xvfb-run -a -s "-screen 0 1200x2000x24" godot47 --path . --write-movie /tmp/orbitpop.avi \
        --fixed-fps 30 --script tests/promo_video.gd
    ffmpeg -i /tmp/orbitpop.avi -c:v libx264 -pix_fmt yuv420p -crf 20 -c:a aac -b:a 128k store/promo_video.mp4

Google Play only takes a **YouTube link** (Play Console > Store presence > Main store listing >
Video). Upload it to YouTube as **Public** or **Unlisted** (not Private), ads off, no age
restriction, and paste the URL.

## YouTube

**Title:** ORBIT POP – One-tap orbit arcade (Android)

**Description:**
One tap to flip your orbit! Dodge meteors, jump between planets, duel your friends on the
same run and beat the daily challenge. 16 worlds, from the clouds to deep space.
Free on Google Play: https://play.google.com/store/apps/details?id=com.barriogames.orbitpop

#arcade #indiegame #pixelart #mobilegame #android
