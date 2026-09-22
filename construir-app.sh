#!/bin/zsh
set -euo pipefail

BASE_DIR="${0:A:h}"
APP="$BASE_DIR/Grabar.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
VERSION="$(tr -d '[:space:]' < "$BASE_DIR/VERSION")"

cd "$BASE_DIR"
swift build -c release --disable-sandbox

mkdir -p "$MACOS" "$RESOURCES"
cp ".build/release/GRBWindowRecApp" "$MACOS/GRBWindowRecApp"
cp "$BASE_DIR/Assets/AppIcon.icns" "$RESOURCES/AppIcon.icns"

/usr/libexec/PlistBuddy -c "Clear dict" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleName string Grabar" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Grabar" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.blackmamba.grabar" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string GRBWindowRecApp" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 15.0" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Add :NSMicrophoneUsageDescription string Grabar necesita el micrófono para incluir audio en tus grabaciones." "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Add :NSAudioCaptureUsageDescription string Grabar necesita capturar el audio del sistema cuando lo activas." "$CONTENTS/Info.plist"

codesign --force --deep --sign - "$APP"
print "App creada en: $APP"
