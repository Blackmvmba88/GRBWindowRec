#!/bin/zsh
set -euo pipefail

FFMPEG="/opt/homebrew/bin/ffmpeg"
BASE_DIR="${0:A:h}"
OUTPUT_DIR="${GRB_RECORDINGS_DIR:-$HOME/Movies/GRBWindowRec}"
MODE="${1:-}"
AUDIO_DEVICE="${AUDIO_DEVICE:-0}"

usage() {
  print "Uso:"
  print "  ./capturar.sh camara"
  print "  ./capturar.sh pantalla"
  print "  ./capturar.sh pantalla2"
  print "  ./capturar.sh dispositivos"
  print ""
  print "Presiona q para detener y guardar correctamente."
  print "Audio predeterminado: dispositivo 0. Puedes cambiarlo con AUDIO_DEVICE=1."
}

if [[ ! -x "$FFMPEG" ]]; then
  print -u2 "No se encontro ffmpeg en $FFMPEG"
  exit 1
fi

case "$MODE" in
  camara)
    VIDEO_DEVICE="0"
    EXTRA_INPUT=()
    ;;
  pantalla)
    VIDEO_DEVICE="1"
    EXTRA_INPUT=(-capture_cursor 1 -capture_mouse_clicks 1)
    ;;
  pantalla2)
    VIDEO_DEVICE="2"
    EXTRA_INPUT=(-capture_cursor 1 -capture_mouse_clicks 1)
    ;;
  dispositivos)
    print "Dispositivos disponibles (el mensaje final de error es normal):"
    exec "$FFMPEG" -hide_banner -f avfoundation -list_devices true -i ""
    ;;
  -h|--help|"")
    usage
    exit 0
    ;;
  *)
    print -u2 "Modo desconocido: $MODE"
    usage
    exit 2
    ;;
esac

mkdir -p "$OUTPUT_DIR"
STAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
OUTPUT="$OUTPUT_DIR/${MODE}_${STAMP}.mp4"

print "Grabando en: $OUTPUT"
print "Video: dispositivo $VIDEO_DEVICE | Audio: dispositivo $AUDIO_DEVICE"
print "Presiona q para detener."

exec "$FFMPEG" \
  -hide_banner \
  -f avfoundation \
  -framerate 30 \
  "${EXTRA_INPUT[@]}" \
  -i "${VIDEO_DEVICE}:${AUDIO_DEVICE}" \
  -map 0:v:0 -map 0:a:0 \
  -c:v h264_videotoolbox \
  -b:v 5M -maxrate 6M -bufsize 6M \
  -pix_fmt yuv420p \
  -c:a aac -b:a 160k -ar 48000 \
  -movflags +faststart \
  "$OUTPUT"
