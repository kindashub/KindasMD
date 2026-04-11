#!/bin/bash
set -euo pipefail
MOD_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${MOD_DIR}/src/editor"
xcodegen generate
# Restore pinned SPM versions (Package.resolved is outside the gitignored xcodeproj)
RESOLVED_SRC="Package.resolved"
RESOLVED_DST="KindasMDEditor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [[ -f "$RESOLVED_SRC" ]]; then
  mkdir -p "$(dirname "$RESOLVED_DST")"
  cp "$RESOLVED_SRC" "$RESOLVED_DST"
fi
xcodebuild -scheme KindasMDEditor -configuration Debug \
    -derivedDataPath ./build-dd build
cp -R ./build-dd/Build/Products/Debug/KindasMDEditor.app \
    "${MOD_DIR}/app/"
codesign --force --deep --sign - "${MOD_DIR}/app/KindasMDEditor.app"
echo "Installed to app/KindasMDEditor.app"
echo "Creating Dock launcher..."
bash "${MOD_DIR}/scripts/setup-kindasmd.sh"
echo ""
echo "Build complete. Drag ${MOD_DIR}/KindasMD.app to your Dock."
