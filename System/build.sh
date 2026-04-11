#!/bin/bash
set -euo pipefail
MOD_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${MOD_DIR}/src/editor"
xcodegen generate
xcodebuild -scheme KindasMDEditor -configuration Debug \
    -derivedDataPath ./build-dd build
cp -R ./build-dd/Build/Products/Debug/KindasMDEditor.app \
    "${MOD_DIR}/app/"
# Also copy to root for backward compatibility with setup scripts
cp -R ./build-dd/Build/Products/Debug/KindasMDEditor.app \
    "${MOD_DIR}/KindasMDEditor.app"
echo "Installed to app/KindasMDEditor.app and KindasMDEditor.app"
echo "Creating Dock launcher..."
bash "${MOD_DIR}/system/setup-kindasmd.sh"
echo ""
echo "Build complete. Drag ${MOD_DIR}/KindasMD.app to your Dock."
