#!/bin/zsh
# Builds, quits any running copy, and launches PowerInfo Reborn.
set -euo pipefail
cd "${0:A:h}/.."
./Scripts/build.sh
pkill -x PowerInfoReborn 2>/dev/null && sleep 0.5 || true
open "build/PowerInfo Reborn.app" --args "$@"
