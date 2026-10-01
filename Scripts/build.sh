#!/bin/zsh
# Builds "build/PowerInfo Reborn.app" from the Swift package.
set -euo pipefail
cd "${0:A:h}/.."

APP="build/PowerInfo Reborn.app"
ICON="build/AppIcon.icns"

# Universal binary so it runs on both Apple silicon and Intel Macs.
ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}" 2>&1 | grep -vE "^\[|x86_64 architecture is deprecated|ld: warning" || true
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)/PowerInfoReborn"
[[ -x "$BIN" ]] || { echo "Build failed"; exit 1; }

if [[ ! -f "$ICON" || Scripts/make_icon.swift -nt "$ICON" ]]; then
    echo "Rendering app icon…"
    ICONSET="build/AppIcon.iconset"
    rm -rf "$ICONSET" && mkdir -p "$ICONSET"
    swift Scripts/make_icon.swift build/icon_1024.png
    for s in 16 32 128 256 512; do
        sips -z $s $s build/icon_1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
        sips -z $((s * 2)) $((s * 2)) build/icon_1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$ICON"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/PowerInfoReborn"
# Drop debug symbols, which contain local build paths.
strip -S -x "$APP/Contents/MacOS/PowerInfoReborn"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP" >/dev/null

echo "Built $APP"
