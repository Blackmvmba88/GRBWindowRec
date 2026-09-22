#!/bin/zsh
set -euo pipefail

BASE_DIR="${0:A:h}"
APP="$BASE_DIR/Grabar.app"
DEST="$HOME/Applications/Grabar.app"

"$BASE_DIR/construir-app.sh"
rm -rf "$DEST"
cp -R "$APP" "$DEST"
open "$DEST"
print "GRB Window Rec instalado en: $DEST"
