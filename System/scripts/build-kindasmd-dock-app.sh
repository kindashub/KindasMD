#!/usr/bin/env bash
# Build ~/MBP-Mods/KindasMD/KindasMD.app — Mach-O launcher + icon (Dock-friendly).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD_DIR="${HOME}/MBP-Mods/KindasMD"
SYS_DIR="${MOD_DIR}/system"
DOCK_APP="${MOD_DIR}/KindasMD.app"
BIN_LAUNCHER="${SYS_DIR}/kindasmd"
LAUNCHER_C="${SCRIPT_DIR}/kindasmd-launcher.c"

if [[ ! -x "$BIN_LAUNCHER" ]]; then
  echo "error: missing executable ${BIN_LAUNCHER}" >&2
  echo "Run: ${SYS_DIR}/setup-kindasmd.sh" >&2
  exit 1
fi

if [[ ! -f "$LAUNCHER_C" ]]; then
  echo "error: missing ${LAUNCHER_C}" >&2
  exit 1
fi

if ! command -v clang >/dev/null 2>&1; then
  echo "error: clang not found (install Xcode Command Line Tools)" >&2
  exit 1
fi

echo "==> Building ${DOCK_APP}"
rm -rf "$DOCK_APP"
mkdir -p "${DOCK_APP}/Contents/MacOS" "${DOCK_APP}/Contents/Resources"

clang -O2 -Wall -Wextra \
  -arch arm64 -arch x86_64 \
  -o "${DOCK_APP}/Contents/MacOS/KindasMD" \
  "$LAUNCHER_C"

ICON_OUT="${DOCK_APP}/Contents/Resources/KindasMD.icns"
EDITOR="${MOD_DIR}/KindasMDEditor.app"
if [[ -f "${EDITOR}/Contents/Resources/AppIcon.icns" ]]; then
  cp "${EDITOR}/Contents/Resources/AppIcon.icns" "$ICON_OUT"
elif [[ -f "${EDITOR}/Contents/Resources/applet.icns" ]]; then
  cp "${EDITOR}/Contents/Resources/applet.icns" "$ICON_OUT"
elif [[ -f "/System/Applications/TextEdit.app/Contents/Resources/EditText.icns" ]]; then
  cp "/System/Applications/TextEdit.app/Contents/Resources/EditText.icns" "$ICON_OUT"
elif [[ -f "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns" ]]; then
  cp "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns" "$ICON_OUT"
fi

cat > "${DOCK_APP}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>KindasMD</string>
	<key>CFBundleExecutable</key>
	<string>KindasMD</string>
	<key>CFBundleIconFile</key>
	<string>KindasMD</string>
	<key>CFBundleIdentifier</key>
	<string>com.kindasmd.dock</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>KindasMD</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>2.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>11.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep -s - "$DOCK_APP" 2>/dev/null || true
fi

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f -R -trusted "$DOCK_APP" 2>/dev/null || true
fi

echo "==> KindasMD.app ready (Mach-O launcher + icon)."
