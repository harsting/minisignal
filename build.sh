#!/bin/bash
# Baut MiniSignal.app — braucht nur die Command Line Tools, kein Xcode.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="MiniSignal"
BUILD_DIR=".build/release"
APP="$APP_NAME.app"

echo "==> Kompiliere ..."
swift build -c release

echo "==> Baue $APP ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -d Resources/Carriers ] && cp -R Resources/Carriers "$APP/Contents/Resources/"

echo "==> Signiere (ad hoc) ..."
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || {
    echo "    Signieren fehlgeschlagen — die App läuft trotzdem, macOS fragt evtl. öfter nach."
}

echo
echo "Fertig: $(pwd)/$APP"
echo "Starten mit:  open $APP"
