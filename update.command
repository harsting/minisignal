#!/bin/bash
# Holt die neueste Version, baut sie, installiert sie und startet MiniSignal neu.
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Hole Neuerungen von GitHub ..."
git pull --ff-only

./build.sh

echo "==> Beende laufendes MiniSignal ..."
pkill -x MiniSignal 2>/dev/null || true

# Die App gehört nach /Applications — sonst zeigt das Anmeldeobjekt auf eine
# alte Kopie und man aktualisiert am eigenen Alltagsstart vorbei.
TARGET="/Applications/MiniSignal.app"
if [ ! -w /Applications ]; then
    mkdir -p "$HOME/Applications"
    TARGET="$HOME/Applications/MiniSignal.app"
    echo "    (/Applications ist gesperrt — installiere nach $HOME/Applications)"
fi

echo "==> Installiere nach $TARGET ..."
rm -rf "$TARGET"
ditto MiniSignal.app "$TARGET"

echo "==> Starte neu ..."
open "$TARGET"

echo
echo "Fertig — MiniSignal läuft jetzt in Version $(/usr/libexec/PlistBuddy \
    -c "Print :CFBundleShortVersionString" "$TARGET/Contents/Info.plist")."
