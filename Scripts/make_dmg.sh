#!/bin/zsh
# Builds the app and packages it as build/PowerInfo-Reborn-<version>.dmg,
# with a shortcut to Applications so it can be dragged across to install.
set -euo pipefail
cd "${0:A:h}/.."

./Scripts/build.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
DMG="build/PowerInfo-Reborn-$VERSION.dmg"
STAGE="build/dmg"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "build/PowerInfo Reborn.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "PowerInfo Reborn" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" 2>&1 | grep -v "is deprecated" || true
rm -rf "$STAGE"

echo "Created $DMG"
