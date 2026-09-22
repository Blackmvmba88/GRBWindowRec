#!/bin/zsh
set -euo pipefail

BASE_DIR="${0:A:h}"
APP="$BASE_DIR/GRB Window Recorder.app"
DEST="$HOME/Applications/GRB Window Recorder.app"

"$BASE_DIR/construir-app.sh"
rm -rf "$DEST"
cp -R "$APP" "$DEST"
open "$DEST"
print "GRB Window Recorder instalado en: $DEST"
