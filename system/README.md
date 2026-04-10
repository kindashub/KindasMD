# KindasMD — `system/`

**User entry:** **`KindasMD.app`** (Dock) only — it runs **`kindasmd`**, which opens **`KindasMDEditor.app`**. After **`xcodebuild`**, copy **`KindasMDEditor.app`** to **`~/MBP-Mods/KindasMD/KindasMDEditor.app`** so Dock launches match your build (see repo **[README.md](../README.md)**).

| File | Role |
|------|------|
| **setup-kindasmd.sh** | Installs **`kindasmd`** launcher, runs **purge-stale-kindasmd.sh** (Launch Services + `duti`), builds **KindasMD.app**. |
| **purge-stale-kindasmd.sh** | Unregisters extra **KindasMDEditor.app** copies (DerivedData, old paths), re-registers **`~/MBP-Mods/KindasMD/KindasMDEditor.app`**. **`--kill-editor`** terminates running **KindasMDEditor** so Finder stops sending files to an old process. **`--delete-derived`** removes the Debug app under `src/editor/.derivedData`. |
| **kindasmd** | New note in `~/TextMD`; uses **`open -na`** so Dock always starts the MBP-Mods editor. |
| **kindasmd-new-md.sh** | Deprecated wrapper that **`exec`s `kindasmd`**. |
| **build-kindasmd-dock-app.sh** | Builds **KindasMD.app** (Mach-O + icon). |
| **verify-kindasmd-editor.sh** | Sanity-check **KindasMDEditor.app**. |
| **kindasmd-launcher.c** | Tiny binary for Dock bundle `CFBundleExecutable`. |

Editor sources: **[../src/editor/](../src/editor/)** (`xcodegen` + **KindasMDEditor.xcodeproj**).
