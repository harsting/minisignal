#!/bin/bash
# Holt die neueste Version, baut sie und startet MiniSignal neu.
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Hole Neuerungen von GitHub ..."
git pull --ff-only

./build.sh

echo "==> Starte MiniSignal neu ..."
pkill -x MiniSignal 2>/dev/null || true
open MiniSignal.app

echo
echo "Fertig. MiniSignal läuft in der neuen Version."
