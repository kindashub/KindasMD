#!/usr/bin/env bash
# Sanity-check KindasMDEditor.app: Swift app, not a Script Editor applet.

set -euo pipefail

APP="${HOME}/MBP-Mods/KindasMD/KindasMDEditor.app"
if [[ ! -d "$APP" ]]; then
  echo "error: missing ${APP}" >&2
  echo "Build: cd ~/MBP-Mods/KindasMD/src/editor && xcodegen generate && xcodebuild -scheme KindasMDEditor -configuration Debug -derivedDataPath ./build-dd build" >&2
  exit 1
fi

EXE="$(defaults read "$APP/Contents/Info" CFBundleExecutable 2>/dev/null || echo "")"
BID="$(defaults read "$APP/Contents/Info" CFBundleIdentifier 2>/dev/null || echo "")"

echo "KindasMDEditor.app CFBundleExecutable: ${EXE:-?}"
echo "KindasMDEditor.app CFBundleIdentifier: ${BID:-?}"

if [[ "$EXE" == "applet" ]] || [[ -z "$EXE" ]]; then
  echo "error: wrong bundle (applet or incomplete)" >&2
  exit 1
fi

if [[ "$BID" != com.kindasmd.editor ]]; then
  echo "note: expected com.kindasmd.editor, got ${BID}"
fi

exit 0
