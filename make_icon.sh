#!/bin/bash
# Erzeugt Resources/MiniSignal.icns aus dem gezeichneten Symbol.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release >/dev/null
SET="$(mktemp -d)/MiniSignal.iconset"
MINISIGNAL_ICONSET="$SET" .build/release/MiniSignal >/dev/null 2>&1
iconutil -c icns "$SET" -o Resources/MiniSignal.icns
echo "Fertig: Resources/MiniSignal.icns"
