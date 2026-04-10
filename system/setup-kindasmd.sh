#!/usr/bin/env bash
# KindasMD: install launcher script, purge stale LS registrations, Dock app, optional duti.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_LAUNCHER="${SCRIPT_DIR}/kindasmd"
MOD_DIR="${HOME}/MBP-Mods/KindasMD"
SYS_DIR="${MOD_DIR}/system"
BIN_LAUNCHER="${SYS_DIR}/kindasmd"
DEFAULT_DIR="${TEXTEDIT_DEFAULT_DIR:-$HOME/TextMD}"
EDITOR_APP="${MOD_DIR}/KindasMDEditor.app"
BUILD_DOCK="${SCRIPT_DIR}/build-kindasmd-dock-app.sh"

if [[ ! -f "$SRC_LAUNCHER" ]]; then
  echo "error: missing ${SRC_LAUNCHER}" >&2
  exit 1
fi

echo "==> KindasMD: ${MOD_DIR}"
mkdir -p "$SYS_DIR" "$DEFAULT_DIR"

echo "==> Install launcher: ${BIN_LAUNCHER}"
if [[ ! "$SRC_LAUNCHER" -ef "$BIN_LAUNCHER" ]]; then
  cp "$SRC_LAUNCHER" "$BIN_LAUNCHER"
fi
chmod +x "$BIN_LAUNCHER"

PURGE_SCRIPT="${SCRIPT_DIR}/purge-stale-kindasmd.sh"
if [[ -d "$EDITOR_APP" && -f "$PURGE_SCRIPT" ]]; then
  bash "$PURGE_SCRIPT"
elif [[ ! -d "$EDITOR_APP" ]]; then
  echo "Tip: copy KindasMDEditor.app to ${EDITOR_APP}, then re-run setup (or ${PURGE_SCRIPT}) so Finder and double-click .md use the current build."
fi

if [[ "$(uname -s)" == Darwin && -x "$BUILD_DOCK" ]]; then
  echo "==> Dock helper (KindasMD.app)"
  bash "$BUILD_DOCK"
fi

echo ""
echo "-------------------------------------------------------------------"
echo "Editor:   ${EDITOR_APP}"
echo "New note: ${BIN_LAUNCHER}"
echo "Dock:     ${MOD_DIR}/KindasMD.app"
echo "MASTER:   ~/TextMD/MASTER"
echo "-------------------------------------------------------------------"
