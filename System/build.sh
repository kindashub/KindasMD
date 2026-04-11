#!/bin/bash
set -euo pipefail
MOD_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${MOD_DIR}/src/editor"
xcodegen generate
xcodebuild -scheme KindasMDEditor -configuration Debug \
    -derivedDataPath ./build-dd build
cp -R ./build-dd/Build/Products/Debug/KindasMDEditor.app \
    "${MOD_DIR}/app/"
echo "Installed to app/KindasMDEditor.app"
echo "Creating Dock launcher..."
bash "${MOD_DIR}/scripts/setup-kindasmd.sh"
echo ""
echo "Build complete. Drag ${MOD_DIR}/KindasMD.app to your Dock."
