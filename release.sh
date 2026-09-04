#!/bin/bash
# Baut MiniSignal und packt es als ZIP für ein GitHub-Release.
set -euo pipefail

cd "$(dirname "$0")"

./build.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
          MiniSignal.app/Contents/Info.plist)
ZIP="MiniSignal-$VERSION.zip"

echo "==> Packe $ZIP ..."
rm -f "$ZIP"
ditto -c -k --keepParent MiniSignal.app "$ZIP"

echo
echo "Fertig: $(pwd)/$ZIP"
echo
echo "Hochladen (einmal 'brew install gh' und 'gh auth login' vorausgesetzt):"
echo "  gh release create v$VERSION \"$ZIP\" \\"
echo "     --title \"MiniSignal $VERSION\" \\"
echo "     --notes \"Mehrere Geräte, einstellbarer Kurzbefehl, Einladungslink.\""
