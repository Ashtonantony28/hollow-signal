#!/usr/bin/env bash
# Regenerate docs/media/: headless gameplay capture with the autoplay bot.
# Needs: godot 4.3 on PATH (or GODOT=...), xvfb-run, ffmpeg.
set -euo pipefail
G=${GODOT:-godot}; OUT=docs/media; TMP=$(mktemp -d); mkdir -p "$OUT"
cap() { xvfb-run -a -s "-screen 0 1280x720x24" "$G" --path . --resolution 1280x720 \
          --write-movie "$TMP/$1.avi" --fixed-fps 30 -- "${@:2}"; }
"$G" --headless --path . --import >/dev/null 2>&1 || true
cap run  --autoplay --god --seed=7  --skip-menu --quit-after=40
cap run2 --autoplay --god --seed=21 --deck=3 --skip-menu --quit-after=40
cap menu --quit-after=6
seg() { ffmpeg -v error -y -ss "$2" -t "$3" -i "$TMP/$1.avi" -vf scale=1280:720,fps=30 -an \
          -c:v libx264 -crf 18 -pix_fmt yuv420p "$TMP/$4.mp4"; }
seg menu 3 2.5 s0; seg run2 0.5 6 s1; seg run 5 7 s2; seg run2 24 9 s3; seg run 25 6 s4
printf "file '$TMP/s%d.mp4'\n" 0 1 2 3 4 > "$TMP/all.txt"
ffmpeg -v error -y -f concat -safe 0 -i "$TMP/all.txt" -c:v libx264 -crf 30 -preset slow \
  -pix_fmt yuv420p -movflags +faststart "$OUT/hollow-signal-gameplay.mp4"
printf "file '$TMP/s%d.mp4'\n" 1 3 > "$TMP/gif.txt"
ffmpeg -v error -y -f concat -safe 0 -i "$TMP/gif.txt" -t 10 -vf "fps=10,scale=560:-1:flags=lanczos,hqdn3d=3:3:4:4,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=none:diff_mode=rectangle" "$OUT/hollow-signal-gameplay.gif"
shot() { ffmpeg -v error -y -ss "$2" -i "$TMP/$1.avi" -frames:v 1 -q:v 3 "$OUT/$3.jpg"; }
shot run2 3 shot-corridor; shot run 8 shot-swarm; shot run2 27 shot-shield-bands; shot menu 4 shot-menu
rm -rf "$TMP"; ls -la "$OUT"
