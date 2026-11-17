#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/dist/knURLink.app}"
DMG="${2:-$ROOT/dist/knURLink.dmg}"
VOLUME="knURLink"
STAGING="$(mktemp -d)"

if [ ! -d "$APP" ]; then
    echo "App bundle not found: $APP" >&2
    exit 1
fi

hdiutil detach "/Volumes/$VOLUME" -force 2>/dev/null || true
rm -f "$DMG"
cp -R "$APP" "$STAGING/knURLink.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -srcfolder "$STAGING" -volname "$VOLUME" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null
rm -rf "$STAGING"
echo "Created $DMG"
