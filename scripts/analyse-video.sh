#!/bin/zsh
# Découpe une vidéo de jeu pour l'analyse des bugs graphiques.
#   analyse/<nom>/images/s0001.jpg ...  1 image par seconde (s0001 = seconde 0)
#   analyse/<nom>/planches/p001.jpg ... planches 4x3 (12 secondes par planche)
# Usage : scripts/analyse-video.sh <vidéo>
set -euo pipefail

ROOT=${0:A:h:h}
video=${1:?usage : analyse-video.sh <vidéo>}
name=${${video:t:r}// /_}
out=$ROOT/analyse/$name
mkdir -p $out/images $out/planches

ffprobe -v error -show_entries format=duration:stream=width,height,r_frame_rate \
  -of default=noprint_wrappers=1 "$video" | sort -u

ffmpeg -hide_banner -loglevel error -y -i "$video" \
  -vf "fps=1,scale=1920:-2" -q:v 3 $out/images/s%04d.jpg
ffmpeg -hide_banner -loglevel error -y -i "$video" \
  -vf "fps=1,scale=640:-2,tile=4x3" -q:v 4 $out/planches/p%03d.jpg

print "images  : $(ls $out/images | wc -l | tr -d ' ') dans $out/images"
print "planches: $(ls $out/planches | wc -l | tr -d ' ') dans $out/planches (planche N = secondes $(( 0 ))+12*(N-1) à 12*N-1)"
