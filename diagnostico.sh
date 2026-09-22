#!/bin/zsh
set -euo pipefail

print "GRB Window Rec — diagnóstico"
print "macOS: $(sw_vers -productVersion)"
print "Arquitectura: $(uname -m)"

if (( $+commands[ffmpeg] )); then
  print "✓ FFmpeg: $(command -v ffmpeg)"
  ffmpeg -hide_banner -version | head -1
else
  print -u2 "✗ FFmpeg no está instalado. Instala con: brew install ffmpeg"
fi

if [[ -d "$HOME/Movies" ]]; then
  integer free_kb=$(df -Pk "$HOME/Movies" | awk 'NR==2 {print $4}')
  print "✓ Espacio libre en Movies: $((free_kb / 1024 / 1024)) GB"
fi

print ""
print "Permisos: revisa Grabación de pantalla y Micrófono para GRB Window Rec."
print "Salida: $HOME/Movies/GRBWindowRec"
