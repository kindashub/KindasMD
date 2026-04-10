---
name: KindasMD V2 Build
overview: "Root-cause-driven V2 build under Master Rule 1. Five sessions with hard stops. Session 0 establishes the project as its own self-contained entity with its own repo, README-driven agent workflow, and archived V1. Sessions 1-4 build V2."
todos:
  - id: s0-archive
    content: "SESSION 0 | Archive all V1 contents into KindasMD-V1-Archived/, compress to .tar.gz"
    status: pending
  - id: s0-structure
    content: "SESSION 0 | Create new V2 folder structure with plans/, handoffs/, docs/, app/"
    status: pending
  - id: s0-readme
    content: "SESSION 0 | Write README.md -- the single entry point for any agent"
    status: pending
  - id: s0-claude
    content: "SESSION 0 | Write clean CLAUDE.md for V2 (not inherited from V1)"
    status: pending
  - id: s0-repo
    content: "SESSION 0 | Create KindasMD GitHub repo, initial commit, push"
    status: pending
  - id: s0-plan-copy
    content: "SESSION 0 | Copy this plan into plans/v2-build-plan.md (the SOT copy)"
    status: pending
  - id: s1-sparkle
    content: "SESSION 1 | Remove Sparkle from project.yml, ClearlyApp.swift, SettingsView.swift"
    status: pending
  - id: s1-pin-deps
    content: "SESSION 1 | Pin SPM dependency versions to exact in project.yml"
    status: pending
  - id: s1-force-unwraps
    content: "SESSION 1 | Guard all force-unwraps across 7 files (16 occurrences)"
    status: pending
  - id: s1-redundant-refresh
    content: "SESSION 1 | Remove redundant masterFolder.ensureFolderAndRefresh() in onChange(mode)"
    status: pending
  - id: s1-font-density
    content: "SESSION 1 | Reduce lineSpacing (8->3), editorInsetX (60->24), editorInsetBottom (40->20)"
    status: pending
  - id: s1-build-script
    content: "SESSION 1 | Create build.sh, build + verify + commit + push"
    status: pending
  - id: s2-scroll-rewrite
    content: "SESSION 2 | Replace fraction scroll with line-number-based position (atomic rewrite)"
    status: pending
  - id: s2-scroll-verify
    content: "SESSION 2 | Test edit->preview->edit scroll preservation, commit + push"
    status: pending
  - id: s3-webview-guards
    content: "SESSION 3 | Add WKWebView lifecycle guards in PreviewView"
    status: pending
  - id: s3-extract-master
    content: "SESSION 3 | Extract MasterFolderModel from KindasStripView to own file"
    status: pending
  - id: s3-palette
    content: "SESSION 3 | Expand box palette to 41x5, bigger cells, Greek+math row"
    status: pending
  - id: s3-build-verify
    content: "SESSION 3 | Build, stress-test, commit + push"
    status: pending
  - id: s4-quickcopy
    content: "SESSION 4 | Implement Quick Copy Buttons"
    status: pending
  - id: s4-browser
    content: "SESSION 4 | Implement TextEdit File Browser"
    status: pending
  - id: s4-final-verify
    content: "SESSION 4 | Final build + full verification + commit + push"
    status: pending
isProject: false
---

# KindasMD V2 Build Plan (Revised v2)

> **Master Rule 1:** "Understand the whole, then change the smallest correct thing. Before acting, you must be able to describe the system's purpose, constraints, and relationships completely. If an assumption could break the result, you are not ready. When acting, make the smallest change that reaches the root cause. Every element must earn its place."

---

## Why This Revision Exists

The original plan stored itself in `.cursor/plans/<uuid>.plan.md` -- a hidden folder with a UUID filename. Cold-start agents could never find it. The project's knowledge was scattered: report in one place, plan in another, CLAUDE.md inherited from V1, code in a subfolder of a larger repo. No agent could understand the project without being hand-fed context.

This revision fixes the root cause: **the project folder itself becomes the source of truth.** A new agent reads `README.md` and knows everything. Plans, handoffs, docs, source, build scripts -- all live inside one self-contained project folder backed by its own GitHub repo.

---

## Critical Review: What Was Corrected (from v1 of this plan)

- **Crash handler -- REMOVED.** `NSSetUncaughtExceptionHandler` catches ObjC `NSException`, not `EXC_BAD_ACCESS`. Wrong tool for the actual crash types.
- **Configurable spacing sliders -- REMOVED.** User asked for compactness, not sliders. Speculative UI.
- **ScrollBridge lock -- REMOVED.** All access is main-thread. Lock adds complexity for a non-existent race.
- **Async MasterFolderModel I/O -- REMOVED.** Files are tiny .md notes. Over-engineering.
- **Force-unwrap in scroll code sample -- FIXED.** Used `guard let` instead.
- **Preview->edit line mapping -- HONESTLY STATED** as `fraction * totalLineCount` approximation (no cmark-gfm source maps exist).
- **TextEdit Browser file opening -- CORRECTED** to `NSDocumentController.shared.openDocument` (new window, per macOS DocumentGroup convention).
- **xcodegen syntax -- FIXED.** `version:` not `exactVersion:`.
- **OutlineState `try!` -- KEPT.** Compile-time constant regex patterns cannot fail.

---

## Session Map

```
SESSION 0: Project Structure + Archive + Repo
  Difficulty: LOW    Risk: LOW    ~30 min
  Archive V1, folder structure, README, CLAUDE.md, GitHub repo
                           |
  ======================== HARD STOP 0 ========================
                           |
SESSION 1: Foundation + Font Density
  Difficulty: LOW    Risk: LOW    ~1-2 hours
  Remove Sparkle, pin deps, guard force-unwraps, fix font density
                           |
  ======================== HARD STOP 1 ========================
                           |
SESSION 2: Scroll Sync Rewrite (THE HARD ONE)
  Difficulty: HIGH   Risk: HIGH   ~3-5 hours
  Atomic rewrite: line-number-based scroll, remove all band-aids
                           |
  ======================== HARD STOP 2 ========================
                           |
SESSION 3: Crash Prevention + Palette Enhancement
  Difficulty: MEDIUM  Risk: MEDIUM  ~2-3 hours
  WKWebView guards, MasterFolderModel extraction, palette 41x5
                           |
  ======================== HARD STOP 3 ========================
                           |
SESSION 4: New Features (Additive Only)
  Difficulty: MEDIUM  Risk: LOW   ~2-3 hours
  Quick Copy Buttons + TextEdit File Browser. Tag v2.0.
```

---

## SESSION 0: Project Structure + Archive + GitHub Repo

**Goal:** Transform `~/MBP-Mods/KindasMD/` from a subfolder of a monorepo into a self-contained project with its own identity, GitHub repo, and agent-readable structure.

### 0A. Archive V1

1. Create temporary staging: `mkdir ~/MBP-Mods/KindasMD-V1-Archived`
2. Move ALL current contents of `~/MBP-Mods/KindasMD/` into it
3. Compress: `cd ~/MBP-Mods && tar -czf KindasMD-V1-Archived.tar.gz KindasMD-V1-Archived/`
4. Recreate empty `~/MBP-Mods/KindasMD/`
5. Move the `.tar.gz` into `~/MBP-Mods/KindasMD/_archive/`
6. Remove the uncompressed staging folder
7. Commit the V1 removal to MBP-Mods repo so it's preserved in git history

### 0B. Create V2 folder structure

```
~/MBP-Mods/KindasMD/
├── README.md                     # THE agent entry point
├── CLAUDE.md                     # Clean V2 context
├── CHANGELOG.md                  # Running changelog (start fresh)
├── .gitignore
├── build.sh                      # One-command build + install
│
├── plans/                        # All plans live here (findable!)
│   └── v2-build-plan.md          # THIS plan, copied here
│
├── handoffs/                     # Session handoff notes
│   └── _template.md              # Handoff template
│
├── docs/                         # Reference documents
│   └── v2-report.md              # The V2 blueprint report
│
├── src/
│   └── editor/
│       ├── project.yml
│       ├── Clearly/              # Swift source (29 files)
│       ├── ClearlyQuickLook/
│       ├── Shared/
│       └── (other editor files from V1 src/editor/)
│
├── system/                       # Launcher scripts
│   ├── kindasmd                  # Bash launcher
│   ├── kindasmd-launcher.c       # Mach-O source
│   └── (other system scripts)
│
├── app/                          # Installed .app bundles
│   ├── KindasMD.app              # Dock launcher
│   └── KindasMDEditor.app        # Editor (build output)
│
└── _archive/                     # Compressed V1 (reference only)
    └── KindasMD-V1-Archived.tar.gz
```

**What carries over from V1:** `src/`, `system/`, `.app` bundles (into `app/`).

**What does NOT carry over:** `_upstream_kindasos/` (separate project, stays in MBP-Mods git history), `backups/` (git + archive replaces this), old loose docs (`CONTINUATION.md`, `HandoffSummery.md`, `kindasmd_v2_roadmap.md` -- superseded by this plan and `docs/v2-report.md`), old `CLAUDE.md` (replaced with clean V2 version), old `README.md` (replaced).

### 0C. Write README.md

The most important file. Any agent reading this understands everything.

**Contents (full draft):**

```markdown
# KindasMD

A macOS Markdown editor. Swift / SwiftUI / AppKit.

## For Agents: Read This First

This README is your complete operating guide. If you were told "readme" -- this is it.

### Master Rules

1. "Understand the whole, then change the smallest correct thing. Before acting,
   you must be able to describe the system's purpose, constraints, and
   relationships completely. If an assumption could break the result, you are
   not ready. When acting, make the smallest change that reaches the root cause.
   Every element must earn its place."

2. After EVERY completed execution (session end, hard stop, or task completion),
   you MUST:
   (a) Save a handoff note to handoffs/YYYYMMDD-HHMMSS.md
   (b) Provide the user a COPYABLE cold-start message for the next agent:

       Read ~/MBP-Mods/KindasMD/README.md -- it tells you everything.
       Check handoffs/ for the latest session note.
       The active plan is at plans/v2-build-plan.md.

### Source of Truth (SOT)

This folder (~/MBP-Mods/KindasMD/) is the source of truth.
Everything needed to understand, build, and extend KindasMD lives here.

### GitHub Sync

Repo: https://github.com/kindashub/KindasMD (separate from MBP-Mods)

- The SOT folder is the primary. The repo is a backup/sync target.
- After every session that changes code or docs, commit and push:
  git add -A && git commit -m "description" && git push
- The repo must always reflect the current SOT folder state.
- If this machine is lost, clone the repo to recreate everything,
  then run bash build.sh.

### Operating Procedures

1. Read this README
2. Read CLAUDE.md for technical context
3. Check plans/ for the active plan
4. Check handoffs/ for the latest handoff
5. Build: bash build.sh (then Dock-launch KindasMD.app)
6. After work: commit, push, write handoff, give user the cold-start message

### Folder Structure

- src/editor/Clearly/  -- Swift source files (the editor app)
- src/editor/project.yml -- xcodegen project definition
- system/ -- Dock launcher scripts (kindasmd, kindasmd-launcher.c)
- app/ -- installed .app bundles (KindasMD.app + KindasMDEditor.app)
- plans/ -- build plans (always here, never in .cursor/plans/)
- handoffs/ -- session handoff notes
- docs/ -- reference documents (V2 report, etc.)
- _archive/ -- compressed V1 archive (reference only, do not extract)

### Key Technical Facts

- Deployment target: macOS 14.0, Swift 5.9
- SPM deps: cmark-gfm (MD->HTML), KeyboardShortcuts
- Sandbox: DISABLED (required for ~/TextMD file access)
- Build: xcodegen generate + xcodebuild (see build.sh)
- Launcher: KindasMD.app (Dock) -> system/kindasmd -> open -na KindasMDEditor.app
- The -n flag is critical: without it macOS reuses stale processes
- Working directory: ~/TextMD/ (new docs created here)
- MASTER notes: ~/TextMD/MASTER/

### Do NOT

- Do NOT use .cursor/plans/ for plans -- use plans/ in this project
- Do NOT force-push or rewrite git history
- Do NOT casually refactor the HSplitView block in ContentView.swift
- Do NOT add Sparkle or any auto-update framework
- Do NOT skip the handoff note at session end
```

### 0D. Write CLAUDE.md

Clean V2 version (no V1 baggage):

```markdown
# KindasMD -- Agent Context

macOS Markdown editor. Swift/SwiftUI/AppKit. Sources: src/editor/Clearly/.

## Start Here

Read README.md in this folder for master rules, operating procedures,
folder structure, and GitHub sync instructions.

Check plans/ for the active build plan.
Check handoffs/ for the latest session note.

## Build

bash build.sh
Then Dock-launch KindasMD.app.

## Architecture

Two .app bundles:
- KindasMD.app: Dock launcher (calls system/kindasmd script)
- KindasMDEditor.app: the editor (built from src/editor/)

Window layout: toolbar + optional box palette + optional column ruler +
editor/split/preview pane + optional MASTER strip + status bar +
optional outline panel.

Core files:
- ContentView.swift -- main layout, mode switching, toolbar
- EditorView.swift -- NSTextView wrapper, scroll sync, find
- PreviewView.swift -- WKWebView wrapper, HTML render, scroll sync
- Theme.swift -- colors, fonts, spacing constants
- KindasStripView.swift -- box character palette + MASTER strip views
- PositionSync.swift -- scroll position storage (ScrollBridge, ScrollPositionStore)

Key pattern: NSTextView bridged to SwiftUI via NSViewRepresentable (not TextEditor).
This is intentional for undo, find panel, and NSTextStorageDelegate syntax highlighting.
```

### 0E. Create handoff template

Create `handoffs/_template.md`:

```markdown
# Session Handoff: [SESSION_NAME]

**Date:** YYYY-MM-DD
**Session:** N of 5
**Commit:** [hash]

## What Was Done

- (bullet list of completed work)

## Current State

- Build: passing / failing
- Tests: (specific results)

## What To Do Next

- (specific, actionable next steps)
- Reference: plans/v2-build-plan.md, SESSION N+1

## Cold-Start Message

(paste this into a new session)

    Read ~/MBP-Mods/KindasMD/README.md -- it tells you everything.
    Check handoffs/ for this note.
    The plan is at plans/v2-build-plan.md.
    Your task: Session N+1 -- [description].
```

### 0F. Create GitHub repo and initial push

1. The user creates repo `KindasMD` at `https://github.com/kindashub/KindasMD` (or their account)
2. Initialize git and push:
   ```bash
   cd ~/MBP-Mods/KindasMD
   git init
   git remote add origin https://github.com/kindashub/KindasMD.git
   git add -A
   git commit -m "KindasMD V2: initial project structure with archived V1"
   git push -u origin main
   ```
3. Add `KindasMD/` to the parent `~/MBP-Mods/.gitignore` (it now has its own repo)

### 0G. Copy this plan into the project

Copy this file to `~/MBP-Mods/KindasMD/plans/v2-build-plan.md`. That copy becomes the source of truth. Future agents find it by reading the README.

---

## ==================== HARD STOP 0 ====================

**Verify:**
- Folder structure matches 0B
- README.md is complete
- CLAUDE.md is clean V2 context
- GitHub repo exists with initial commit
- V1 archive at `_archive/KindasMD-V1-Archived.tar.gz`
- `~/MBP-Mods/.gitignore` has `KindasMD/`
- `system/kindasmd` script resolves editor from `app/KindasMDEditor.app`

**Cold-start message for Session 1:**

```
Read ~/MBP-Mods/KindasMD/README.md -- it tells you everything.
You are starting Session 1 of the V2 build.
The plan is at plans/v2-build-plan.md -- read the SESSION 1 section.
```

---

## SESSION 1: Foundation + Font Density

**Goal:** Remove dead weight, pin deps, guard unsafe code, fix font density. Zero behavioral regression except intentionally smaller text metrics.

### 1A. Remove Sparkle entirely

**Files:** `src/editor/project.yml`, `src/editor/Clearly/ClearlyApp.swift`, `src/editor/Clearly/SettingsView.swift`

**`project.yml`:**
- Delete `Sparkle:` block from `packages:` (lines 13-15)
- Delete `- package: Sparkle` from `KindasMDEditor` target `dependencies:`

**`ClearlyApp.swift`** -- delete:
- Lines 2-4: `#if canImport(Sparkle)` / `import Sparkle` / `#endif`
- Lines 177-179: `#if canImport(Sparkle)` / `private let updaterController` / `#endif`
- Lines 186-192: `updaterController = SPUStandardUpdaterController(...)` in `init()`
- Lines 219-223: `CommandGroup(after: .appInfo) { CheckForUpdatesView(...) }`
- Lines 348-350: Sparkle branch in `Settings` scene (keep `#else` as only path)
- Lines 445-460: entire `CheckForUpdatesView` struct
- Lines 496-507: entire `CheckForUpdatesViewModel` class

**`SettingsView.swift`** -- delete:
- Lines 4-6: `#if canImport(Sparkle)` / `import Sparkle` / `#endif`
- Lines 9-11: conditional `let updater: SPUUpdater`
- Lines 85-89: "Check for Updates" button block
- Remove `updater` from init (non-Sparkle path becomes only path)

### 1B. Pin SPM versions to exact

In `project.yml`: `from: "2.1.0"` -> `version: "2.1.0"` for cmark-gfm and KeyboardShortcuts.

### 1C. Guard all force-unwraps

| File | Pattern | Lines | Fix |
|------|---------|-------|-----|
| `EditorView.swift` | `textView.textStorage!` | 202, 220, 431, 616, 634 | `guard let storage = textView.textStorage else { return }` |
| `ScratchpadEditorView.swift` | `textView.textStorage!` | 116, 126, 153 | same |
| `OutlineState.swift` | `try! NSRegularExpression` | 22, 26, 30, 34 | KEEP (compile-time constant, cannot fail) |
| `PDFExporter.swift` | `as! NSPrintInfo` | 148 | `guard let info = ... as? NSPrintInfo else { return }` |
| `KindasStripView.swift` | `t.first!` | 32 | `guard let ch = t.first else { return " " }` |
| `ClearlyApp.swift` | `URL(string:)!` | 242 | `guard let url = URL(string:) else { return }` |
| `SettingsView.swift` | `URL(string:)!` | 92, 96 | same |

### 1D. Remove redundant refresh call

In `ContentView.swift` line 275 (inside `.onChange(of: mode)`): delete the `masterFolder.ensureFolderAndRefresh()` call. Mode changes don't affect MASTER folder state.

### 1E. Fix font density

In `Theme.swift`:
- `editorInsetX`: `60` -> `24` (line 35)
- `editorInsetBottom`: `40` -> `20` (line 37)
- `lineSpacing`: `8` -> `3` (line 40)

Flows automatically through `editorLineHeight` into paragraph style.

### 1F. Build script

Create `build.sh` in project root:

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/src/editor"
xcodegen generate
xcodebuild -scheme KindasMDEditor -configuration Debug \
    -derivedDataPath ./build-dd build
cp -R ./build-dd/Build/Products/Debug/KindasMDEditor.app \
    "$(dirname "$0")/app/"
echo "Installed to app/KindasMDEditor.app. Launch via Dock -> KindasMD.app"
```

Update `system/kindasmd` to resolve editor from `app/KindasMDEditor.app`.

### 1G. Commit + push + handoff

```bash
git add -A && git commit -m "Session 1: remove Sparkle, pin deps, guard force-unwraps, fix font density" && git push
```

Write handoff to `handoffs/`.

---

## ==================== HARD STOP 1 ====================

**Verify:** Build, install, Dock-launch. No Sparkle. Font density compact. All features work.

**Cold-start for Session 2:**

```
Read ~/MBP-Mods/KindasMD/README.md -- it tells you everything.
You are starting Session 2 (THE HARD ONE: scroll sync rewrite).
The plan is at plans/v2-build-plan.md -- read SESSION 2 carefully.
Check handoffs/ for the Session 1 note.
```

---

## SESSION 2: Scroll Sync Rewrite

**Goal:** Replace fraction-based scroll with line-number-based tracking for mode switches. Keep fraction sync for split mode. Remove all band-aids. This must be done atomically.

**Why this is hard:** Multiple previous agents have failed. Root cause: `NSTextView.visibleRect`/`bounds.height` are unreliable when hidden via ZStack opacity. Fraction-based sync is fundamentally broken across mode switches.

**The insight:** Line numbers are stable regardless of layout state. Line 200 is always line 200.

### 2A. Add ScrollPositionStore to PositionSync.swift

```swift
enum ScrollPositionStore {
    struct Position {
        let firstVisibleLine: Int
        let fractionalLine: CGFloat
    }
    private static var positions: [String: Position] = [:]
    static func save(_ pos: Position, for id: String) { positions[id] = pos }
    static func restore(for id: String) -> Position? { positions[id] }
}
```

ONLY for mode-switch persistence. `ScrollBridge` stays for split-mode.

### 2B. Add capture/restore to EditorView.swift Coordinator

**Capture** (leaving edit):

```swift
func captureFirstVisibleLine() -> ScrollPositionStore.Position? {
    guard let textView else { return nil }
    guard let layoutManager = textView.layoutManager,
          let textContainer = textView.textContainer else { return nil }
    let glyphIndex = layoutManager.glyphIndex(for: textView.visibleRect.origin, in: textContainer)
    let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
    let prefix = (textView.string as NSString).substring(to: min(charIndex, textView.string.count))
    let lineNumber = prefix.components(separatedBy: "\n").count - 1
    return .init(firstVisibleLine: lineNumber, fractionalLine: 0)
}
```

**Restore** (entering edit):

```swift
func restoreToLine(_ position: ScrollPositionStore.Position) {
    guard let textView else { return }
    guard let layoutManager = textView.layoutManager,
          let textContainer = textView.textContainer else { return }
    let lines = textView.string.components(separatedBy: "\n")
    let targetLine = min(position.firstVisibleLine, max(0, lines.count - 1))
    let charIndex = lines.prefix(targetLine).reduce(0) { $0 + $1.count + 1 }
    let safeIndex = min(charIndex, max(0, textView.string.count - 1))
    let glyphRange = layoutManager.glyphRange(
        forCharacterRange: NSRange(location: safeIndex, length: 0),
        actualCharacterRange: nil)
    let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
    textView.scroll(NSPoint(x: 0, y: rect.origin.y))
}
```

### 2C. Wire into updateNSView

**Leaving edit** (EditorView):
```swift
if let pos = context.coordinator.captureFirstVisibleLine() {
    ScrollPositionStore.save(pos, for: positionSyncID)
}
```

**Entering edit from preview** (EditorView):
```swift
DispatchQueue.main.async { [weak coordinator = context.coordinator] in
    guard let coordinator else { return }
    if let pos = ScrollPositionStore.restore(for: positionSyncID) {
        coordinator.restoreToLine(pos)
    }
}
```

**Leaving preview** (PreviewView -- honest approximation, no source maps):
```swift
let totalLines = text.components(separatedBy: "\n").count
let estimatedLine = Int(Double(totalLines) * min(max(coordinator.scrollFraction, 0), 1))
ScrollPositionStore.save(.init(firstVisibleLine: estimatedLine, fractionalLine: 0), for: positionSyncID)
```

### 2D. Delete scheduleScrollRestoreLeavingPreview

Remove entirely (EditorView.swift lines 338-370). Replaced by 2C.

### 2E. Remove band-aids (same commit as 2A-2D)

**Delete from EditorView.swift:**
- `suppressOutgoingScrollUntil` and all refs
- `previewFedEditorEchoIgnoreUntil` and all refs
- `notePreviewFedEditorScroll` method
- Echo heuristic (lines 513-517)
- `programmaticScrollDepth` counter and guards
- `scrollRestoreGeneration` counter
- All `SCROLL-DIAG` log calls

**Keep:** `isApplyingRemoteScroll`, `computeScrollFraction`, `applyProgrammaticScroll` (all split-mode). `ScrollSyncRelay.swift` unchanged.

### 2F. Commit + push + handoff

---

## ==================== HARD STOP 2 ====================

**Critical checkpoint. Test:**
1. Scroll to line ~200 -> preview -> edit: same position? (NOT bottom)
2. Repeat at line 50, 500, end of doc
3. Split mode scroll sync still works?
4. Rapid mode switching 20x: no crash/jump?

**IF SCROLL FAILS: debug here. Do NOT proceed.**

**Cold-start for Session 3:**

```
Read ~/MBP-Mods/KindasMD/README.md -- it tells you everything.
You are starting Session 3 of the V2 build.
The plan is at plans/v2-build-plan.md -- read SESSION 3.
Check handoffs/ for the Session 2 note.
```

---

## SESSION 3: Crash Prevention + Palette Enhancement

### 3A. WKWebView lifecycle guards

In `PreviewView.swift`: nil out the coordinator's webView reference in `dismantleNSView`. Guard all `evaluateJavaScript` calls with `guard let webView = self.webView else { return }`. Root-cause fix -- no `isBeingDismantled` flag needed.

### 3B. Extract MasterFolderModel

Move lines 180-458 of `KindasStripView.swift` to `MasterFolderModel.swift`. Pure extraction, no functional changes.

### 3C. Expand box palette to 41x5

- `KindasBoxGridConfig.rowCount`: 4 -> 5 (cellCount auto-updates to 205)
- `defaultCells()`: append Greek + math chars to fill row 4 (41 chars)
- `hPad`: 9 -> 12; font scale: `s * 0.58` -> `s * 0.65`
- UserDefaults migration: automatic (old count != new -> use defaults)

### 3D. Commit + push + handoff

---

## ==================== HARD STOP 3 ====================

**Test:** Mode switch stress 50x, palette 5 rows, copy + edit mode.

**Cold-start for Session 4:**

```
Read ~/MBP-Mods/KindasMD/README.md -- it tells you everything.
You are starting Session 4 (FINAL) of the V2 build.
The plan is at plans/v2-build-plan.md -- read SESSION 4.
Check handoffs/ for the Session 3 note.
```

---

## SESSION 4: New Features

### 4A. Quick Copy Buttons

New file `QuickCopyButtons.swift`. `QuickCopyItem` model (Codable, id/label/content), stored in UserDefaults. 3 toolbar buttons + "Edit Clips" toggle. Edit panel matches OutlineView structure (VStack, 200pt, auto-save).

### 4B. TextEdit File Browser

New file `TextEditBrowser.swift`. `TextEditBrowserModel` lists `~/TextMD/*.md` by modification date. Uses `getpwuid(getuid())` for home path. Clones OutlineView structure. Row click: `NSDocumentController.shared.openDocument` (new window). Mutual exclusion with Outline. Directory file watching via `DispatchSource`.

### 4C. Final verification + tag

Full regression pass. Then:

```bash
git add -A && git commit -m "Session 4: Quick Copy buttons, TextEdit browser -- V2 complete" && git push
git tag v2.0 && git push --tags
```

---

## File Change Summary

| File | Session | Action |
|------|---------|--------|
| `project.yml` | 1 | Remove Sparkle, pin versions |
| `ClearlyApp.swift` | 1 | Remove Sparkle (~80 lines) |
| `SettingsView.swift` | 1 | Remove Sparkle blocks |
| `Theme.swift` | 1 | lineSpacing 8->3, editorInsetX 60->24, editorInsetBottom 40->20 |
| `EditorView.swift` | 1+2 | Guard force-unwraps (S1), line-based scroll + remove band-aids (S2) |
| `PreviewView.swift` | 2+3 | Capture line position (S2), WKWebView guards (S3) |
| `PositionSync.swift` | 2 | Add ScrollPositionStore |
| `ContentView.swift` | 1+2+4 | Remove refresh (S1), wire scroll (S2), new panels (S4) |
| `KindasStripView.swift` | 1+3 | Guard force-unwrap (S1), expand grid 41x5 (S3) |
| `ScratchpadEditorView.swift` | 1 | Guard force-unwraps |
| `PDFExporter.swift` | 1 | Guard as! cast |
| **NEW** `MasterFolderModel.swift` | 3 | Extracted from KindasStripView |
| **NEW** `QuickCopyButtons.swift` | 4 | Quick Copy feature |
| **NEW** `TextEditBrowser.swift` | 4 | File browser feature |
| **NEW** `README.md` | 0 | Agent entry point |
| **NEW** `CLAUDE.md` | 0 | V2 context |
| **NEW** `build.sh` | 1 | Build + install script |

**Not created (Master Rule 1):** No crash handler, no spacing sliders, no ScrollBridge lock, no async MasterFolderModel I/O, no subdirectory reorganization.
