#!/usr/bin/env bash
# Renders the social shorts of tests/promo_epic.gd to store/shorts/<variant>.mp4 (1080x1920, 60 fps)
# with their part of "Spin Bonk Repeat" (song start = a bar, so the clip's beat 0 is on the beat).
#   tools/render_shorts.sh /path/Spin_Bonk_Repeat.mp3 [variant ...]
set -euo pipefail
SONG="$1"; shift
cd "$(dirname "$0")/.."
declare -A START=([duel]=14.087 [slowmo]=50.027 [worlds]=36.050 [skins]=18.080 [fail]=0.110)
declare -A DUR=([duel]=12 [slowmo]=12 [worlds]=12 [skins]=12 [fail]=11)
VARIANTS=("${@:-duel slowmo worlds skins fail}")
[ $# -eq 0 ] && VARIANTS=(duel slowmo worlds skins fail)
python3 tools/gen_video_caps.py /tmp/epic/caps > /dev/null
mkdir -p store/shorts
for v in "${VARIANTS[@]}"; do
  d=${DUR[$v]}; s=${START[$v]}
  rm -rf "/tmp/epic/$v" && mkdir -p "/tmp/epic/$v"
  printf '[display]\n\nwindow/size/window_width_override=1080\nwindow/size/window_height_override=1920\nwindow/stretch/mode="canvas_items"\n' > override.cfg
  xvfb-run -a -s "-screen 0 1200x2000x24" godot47 --path . --write-movie "/tmp/epic/$v/f.png" --fixed-fps 60 \
    --script tests/promo_epic.gd -- /tmp/epic/caps "$v" > "/tmp/epic/$v.log" 2>&1 || true
  rm -f override.cfg
  fade=$(python3 -c "print($d - 1.2)")
  ffmpeg -v error -y -framerate 60 -i "/tmp/epic/$v/f%08d.png" -ss "$s" -t "$d" -i "$SONG" -i "/tmp/epic/$v/f.wav" \
    -filter_complex "[1:a]asetpts=PTS-STARTPTS,volume=-1.5dB,afade=t=in:d=0.03,afade=t=out:st=$fade:d=1.2[m];[2:a]atrim=0:$d,asetpts=PTS-STARTPTS,volume=-7dB[x];[m][x]amix=inputs=2:normalize=0,alimiter=limit=0.95[a]" \
    -map 0:v -map "[a]" -t "$d" -c:v libx264 -preset slow -tune animation -crf 16 -pix_fmt yuv420p -r 60 \
    -c:a aac -b:a 256k -movflags +faststart "store/shorts/$v.mp4"
  echo "$v: $(du -h "store/shorts/$v.mp4" | cut -f1)  $(grep -hE 'DUEL CODE|fail:|near miss|DIED' "/tmp/epic/$v.log" | tr '\n' ' ')"
  rm -rf "/tmp/epic/$v"
done
