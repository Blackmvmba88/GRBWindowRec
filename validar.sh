#!/bin/zsh
set -euo pipefail

FFPROBE="/opt/homebrew/bin/ffprobe"
FFMPEG="/opt/homebrew/bin/ffmpeg"
FILE="${1:-}"

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  print -u2 "Uso: ./validar.sh ruta/al/video.mp4"
  exit 2
fi

for tool in "$FFPROBE" "$FFMPEG"; do
  [[ -x "$tool" ]] || { print -u2 "No se encontro $tool"; exit 1; }
done

VIDEO_COUNT="$($FFPROBE -v error -select_streams v -show_entries stream=index -of csv=p=0 "$FILE" | wc -l | tr -d ' ')"
AUDIO_COUNT="$($FFPROBE -v error -select_streams a -show_entries stream=index -of csv=p=0 "$FILE" | wc -l | tr -d ' ')"

print "Archivo: $FILE"
print "Pistas de video: $VIDEO_COUNT"
print "Pistas de audio: $AUDIO_COUNT"

if (( VIDEO_COUNT < 1 || AUDIO_COUNT < 1 )); then
  print -u2 "VALIDACION FALLIDA: falta video o audio."
  exit 1
fi

print "Nivel de audio:"
"$FFMPEG" -hide_banner -nostats -i "$FILE" -map 0:a:0 \
  -af volumedetect -f null /dev/null 2>&1 \
  | grep -E 'mean_volume|max_volume' \
  | sed 's/^.*] /  /'

print "VALIDACION OK: el archivo contiene video y audio."
