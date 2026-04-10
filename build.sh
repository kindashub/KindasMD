#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/src/editor"
xcodegen generate
xcodebuild -scheme KindasMDEditor -configuration Debug \
    -derivedDataPath ./build-dd build
cp -R ./build-dd/Build/Products/Debug/KindasMDEditor.app \
    "$(dirname "$0")/app/"
echo "Installed to app/KindasMDEditor.app. Launch via Dock -> KindasMD.app"
