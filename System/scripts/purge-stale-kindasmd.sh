#!/usr/bin/env bash
# Unregister every KindasMDEditor.app except ~/MBP-Mods/KindasMD/KindasMDEditor.app,
# then re-register the canonical bundle and optionally remove the Xcode DerivedData copy.
# Fixes: double-click .md opens an old DerivedData build while Dock (open -na) uses the new one.
#
# Usage:
#   ./purge-stale-kindasmd.sh              # unregister stale + register canonical + duti + lsregister -gc
#   ./purge-stale-kindasmd.sh --delete-derived   # also rm DerivedData/.../KindasMDEditor.app
#   ./purge-stale-kindasmd.sh --kill-editor      # killall KindasMDEditor (see below — required if Finder keeps opening files in an OLD already-running build)
#
# Run after copying a fresh build to ~/MBP-Mods/KindasMD/KindasMDEditor.app
#
# Why --kill-editor: macOS sends “open this .md” to an EXISTING com.kindasmd.editor process. Launch Services
# registration does not replace that process — you still run build 4 until you quit. Dock uses `open -na` and
# starts a new binary; double-click does not.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CANONICAL="${MOD_DIR}/KindasMDEditor.app"
DERIVED_APP="${MOD_DIR}/src/editor/.derivedData/Build/Products/Debug/KindasMDEditor.app"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

DELETE_DERIVED=0
KILL_EDITOR=0
for arg in "$@"; do
  case "$arg" in
    --delete-derived) DELETE_DERIVED=1 ;;
    --kill-editor) KILL_EDITOR=1 ;;
    -h|--help)
      sed -n '1,20p' "$0"
      exit 0
      ;;
  esac
done

if [[ ! -x "$LSREGISTER" ]]; then
  echo "error: missing ${LSREGISTER}" >&2
  exit 1
fi

canonical_abs=""
if [[ -d "$CANONICAL" ]]; then
  canonical_abs="$(cd "$CANONICAL/.." && pwd)/$(basename "$CANONICAL")"
fi

echo "==> KindasMD Launch Services purge"
echo "    Canonical: ${canonical_abs:-<missing — copy KindasMDEditor.app here first>}"

# Collect all bundles that advertise com.kindasmd.editor (main app only).
unregistered=0
while IFS= read -r app; do
  [[ -z "$app" ]] && continue
  [[ ! -d "$app" ]] && continue
  abs="$(cd "$(dirname "$app")" && pwd)/$(basename "$app")"
  if [[ -n "$canonical_abs" && "$abs" == "$canonical_abs" ]]; then
    continue
  fi
  echo "    Unregister: $abs"
  "$LSREGISTER" -u "$abs" 2>/dev/null || true
  unregistered=$((unregistered + 1))
done < <(mdfind "kMDItemCFBundleIdentifier == 'com.kindasmd.editor'" 2>/dev/null | grep -E '/KindasMDEditor\.app$' || true)

# Always try to peel DerivedData registration (path may not appear in Spotlight yet).
if [[ -d "$DERIVED_APP" ]]; then
  echo "    Unregister DerivedData copy: $DERIVED_APP"
  "$LSREGISTER" -u "$DERIVED_APP" 2>/dev/null || true
fi

if [[ "$DELETE_DERIVED" -eq 1 && -d "$DERIVED_APP" ]]; then
  echo "==> Remove DerivedData app bundle (next xcodebuild will recreate)"
  rm -rf "$DERIVED_APP"
fi

if [[ -n "$canonical_abs" && -d "$canonical_abs" ]]; then
  echo "==> Register canonical (trusted, force)"
  "$LSREGISTER" -f -R -trusted "$canonical_abs"
  echo "==> Garbage-collect Launch Services DB"
  "$LSREGISTER" -gc 2>/dev/null || true
else
  echo "warning: canonical app missing — skipping register; copy KindasMDEditor.app to ${CANONICAL}" >&2
fi

BUNDLE_ID="com.kindasmd.editor"
if [[ -d "$CANONICAL" ]]; then
  BUNDLE_ID="$(defaults read "$CANONICAL/Contents/Info" CFBundleIdentifier 2>/dev/null || echo "$BUNDLE_ID")"
fi

if command -v duti >/dev/null 2>&1 && [[ -d "$CANONICAL" ]]; then
  echo "==> Default app for Markdown → ${BUNDLE_ID}"
  duti -s "$BUNDLE_ID" net.daringfireball.markdown all
  duti -s "$BUNDLE_ID" public.markdown all 2>/dev/null || true
else
  echo "Tip: brew install duti && re-run this script to set system-wide .md default"
fi

echo "==> Done (unregistered ${unregistered} non-canonical path(s))."

if [[ "$KILL_EDITOR" -eq 1 ]]; then
  echo "==> Terminate running KindasMDEditor (so the next open loads the app from disk, not an old process)"
  if killall KindasMDEditor 2>/dev/null; then
    echo "    Stopped KindasMDEditor — save work before re-running with --kill-editor in the future."
  else
    echo "    (no KindasMDEditor process was running)"
  fi
else
  echo "    If double-click .md still shows an old build in the window subtitle, the old app was already running:"
  echo "    quit KindasMD Editor or run:  $0 --kill-editor"
fi
