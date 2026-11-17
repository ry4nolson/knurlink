#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/knURLink.app"
ICON="$ROOT/Resources/AppIcon.icns"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

cd "$ROOT"
swift build -c release

if [ ! -f "$ICON" ]; then
    WORK="$(mktemp -d)"
    ICONSET="$WORK/AppIcon.iconset"
    mkdir -p "$ICONSET"
    swift "$ROOT/scripts/make-icon.swift" "$WORK/icon.png"
    for size in 16 32 128 256 512; do
        sips -z "$size" "$size" "$WORK/icon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        sips -z "$((size * 2))" "$((size * 2))" "$WORK/icon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$ICON"
    rm -rf "$WORK"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/Knurlink" "$APP/Contents/MacOS/Knurlink"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
    DEST="/Applications/knURLink.app"
    pkill -x Knurlink 2>/dev/null || true
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    "$LSREGISTER" -f "$DEST"
    echo "Installed $DEST"
fi
