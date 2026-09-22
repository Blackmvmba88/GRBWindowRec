#!/bin/zsh
set -euo pipefail

BASE_DIR="${0:A:h}"
VERSION="$(tr -d '[:space:]' < "$BASE_DIR/VERSION")"
APP="$BASE_DIR/GRB Window Rec.app"
DIST="$BASE_DIR/dist"
DMG="$DIST/GRB-Window-Rec-$VERSION.dmg"
STAGING="$(mktemp -d /private/tmp/grb-window-rec-dmg.XXXXXX)"

cleanup() {
  rm -rf "$STAGING"
}
trap cleanup EXIT

"$BASE_DIR/construir-app.sh"
mkdir -p "$DIST"
cp -R "$APP" "$STAGING/GRB Window Rec.app"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "GRB Window Rec $VERSION" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG"

print "DMG creado en: $DMG"
shasum -a 256 "$DMG"
