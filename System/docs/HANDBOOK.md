# KindasMD — Build Handbook

Complete reference for rebuilding KindasMD from scratch. This document captures the
full state of the project as of April 2026 (V2.3 "Mono Zen").

---

## 1. What Is KindasMD

KindasMD is a native macOS Markdown editor built with Swift, SwiftUI, and AppKit.
It targets writers who want a fast, distraction-free environment with live preview,
character palettes, scratchpads, and a custom syntax-highlighting color scheme
called **Mono Zen**.

It is a document-based app: each `.md` file opens in its own window. The app
registers as the default handler for Markdown files on macOS.

---

## 2. Prerequisites

| Tool       | Version Used | Install                                    |
|------------|-------------|--------------------------------------------|
| macOS      | 15+ (Sequoia) | —                                         |
| Xcode      | 16.0+       | Mac App Store                              |
| XcodeGen   | 2.45+       | `brew install xcodegen`                    |
| Swift      | 5.9+        | Bundled with Xcode                         |
| Git        | any         | Bundled with Xcode CLT                     |
| codesign   | any         | Bundled with Xcode CLT                     |

Deployment target: **macOS 14.0** (Sonoma). The app builds and runs on 14.0+.

---

## 3. Repository

```
GitHub: https://github.com/kindashub/KindasMD.git
Branch: main
```

Clone and build:

```bash
git clone https://github.com/kindashub/KindasMD.git
cd KindasMD
bash System/build.sh
```

After a successful build, drag `KindasMD.app` (in the repo root) to your Dock.

---

## 4. Folder Structure

```
KindasMD/
├── KindasMD.app              ← Dock launcher (Mach-O binary + icon)
├── README.md                 ← Root-level overview
├── .gitignore
│
└── System/                   ← All project internals
    ├── README.md             ← Agent operating guide + master rules
    ├── AGENTS.md             ← Architecture context for AI agents
    ├── CHANGELOG.md          ← Version history
    ├── build.sh              ← One-command build + install + codesign
    │
    ├── docs/
    │   └── HANDBOOK.md       ← THIS FILE
    │
    ├── plans/                ← Development plans
    ├── handoffs/             ← Session handoff notes
    │
    ├── scripts/
    │   ├── kindasmd          ← CLI launcher (creates TX-*.md, opens editor)
    │   ├── setup-kindasmd.sh ← Post-build: Dock app, LS registration, duti
    │   ├── build-kindasmd-dock-app.sh  ← Builds the Mach-O Dock launcher
    │   ├── purge-stale-kindasmd.sh     ← Unregisters stale app copies
    │   ├── verify-kindasmd-editor.sh   ← Sanity check: app is Swift, not applet
    │   ├── kindasmd-launcher.c         ← C source for the Dock launcher binary
    │   └── kindasmd-new-md.sh          ← Deprecated alias for kindasmd
    │
    ├── app/
    │   └── KindasMDEditor.app  ← The built editor (output of build.sh)
    │
    ├── _archive/             ← Compressed snapshots (gitignored)
    │
    └── src/editor/           ← Xcode project source
        ├── project.yml       ← XcodeGen project specification
        ├── Clearly/          ← Main app Swift sources (33 files, ~5850 LOC)
        ├── ClearlyQuickLook/ ← QuickLook extension sources
        └── Shared/           ← Code + resources shared between app & extension
```

---

## 5. Build Pipeline

### 5.1 What `build.sh` Does

```bash
bash System/build.sh
```

Steps (in order):

1. **XcodeGen** — reads `src/editor/project.yml`, generates `KindasMDEditor.xcodeproj`
2. **xcodebuild** — compiles Debug configuration, output to `build-dd/`
3. **Copy** — copies the built `.app` to `System/app/KindasMDEditor.app`
4. **codesign** — ad-hoc re-signs the copied bundle (critical: `cp -R` invalidates
   the signature; without re-signing, macOS refuses to launch with
   `Taskgated Invalid Signature`)
5. **setup-kindasmd.sh** — builds the Dock launcher, registers the canonical app
   with Launch Services, purges stale registrations, optionally sets `.md` default handler

### 5.2 Two App Bundles

| Bundle                | Role                                                    |
|-----------------------|---------------------------------------------------------|
| `KindasMD.app`        | Dock launcher. Mach-O binary compiled from `kindasmd-launcher.c`. Calls `System/scripts/kindasmd` which runs `open -na KindasMDEditor.app`. |
| `KindasMDEditor.app`  | The actual editor. Built from Swift sources in `src/editor/Clearly/`. |

The `-n` flag in `open -na` is critical: without it, macOS reuses stale processes.

### 5.3 XcodeGen Project Spec (`project.yml`)

Key settings:

```yaml
name: KindasMDEditor
options:
  bundleIdPrefix: com.kindasmd
  deploymentTarget:
    macOS: "14.0"

packages:
  cmark-gfm:
    url: https://github.com/brokenhandsio/cmark-gfm.git
    exactVersion: "2.1.0"
  KeyboardShortcuts:
    url: https://github.com/sindresorhus/KeyboardShortcuts
    exactVersion: "2.1.0"

targets:
  KindasMDEditor:
    type: application
    platform: macOS
    sources: [Clearly, Shared]
    dependencies: [cmark (cmark-gfm), KeyboardShortcuts, KindasMDQuickLook]
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.kindasmd.editor
      SWIFT_VERSION: "5.9"
      CODE_SIGN_ENTITLEMENTS: Clearly/Clearly.entitlements
      INFOPLIST_FILE: Clearly/Info.plist

  KindasMDQuickLook:
    type: app-extension
    platform: macOS
    sources: [ClearlyQuickLook, Shared]
    dependencies: [cmark (cmark-gfm)]
```

### 5.4 Dependencies

| Package             | Version | Purpose                                    |
|---------------------|---------|--------------------------------------------|
| cmark-gfm           | 2.1.0   | Markdown → HTML rendering (GFM tables, strikethrough, etc.) |
| KeyboardShortcuts   | 2.1.0   | Global keyboard shortcut recording/handling |

Both are pinned to exact versions via SPM (resolved by XcodeGen).

### 5.5 Entitlements

- **Sandbox: DISABLED** — required for direct file access to `~/TextMD/` and `~/TextMD/MASTER/`
- Network client: enabled (for loading remote images in preview)
- Print: enabled

---

## 6. Architecture

### 6.1 App Entry Point

`ClearlyApp.swift` defines the `@main` struct. It uses `DocumentGroup` for
document-based lifecycle.

```
DocumentGroup(newDocument: MarkdownDocument()) { file in
    ContentView(document: file.$document, fileURL: file.fileURL)
}
.windowToolbarStyle(.unifiedCompact(showsTitle: true))
.defaultSize(width: 500, height: 400)
```

### 6.2 Core Pattern: NSTextView in SwiftUI

The editor does NOT use SwiftUI's `TextEditor`. Instead it wraps `NSTextView`
via `NSViewRepresentable` for:
- Full undo/redo support
- `NSTextStorageDelegate`-based syntax highlighting
- Native find panel
- Custom insertion point drawing
- Spell-check persistence

### 6.3 Key Source Files

| File | LOC | Role |
|------|-----|------|
| `ContentView.swift` | 404 | Main window layout: toolbar, control bar, mode switching (edit/split/preview), panel toggling |
| `EditorView.swift` | 622 | `NSViewRepresentable` wrapping `ClearlyTextView` (NSTextView subclass), scroll sync, find highlights |
| `PreviewView.swift` | 551 | `WKWebView` wrapper for live Markdown preview, scroll sync |
| `ClearlyApp.swift` | 453 | App entry point, document scenes, menu commands, scratchpad window, settings |
| `Theme.swift` | 170 | Mono Zen color palette, fonts, spacing constants |
| `MarkdownSyntaxHighlighter.swift` | 309 | Regex-based syntax highlighting via `NSTextStorage` attributes |
| `KindasStripView.swift` | 387 | Box character palette (41x5 grid) + MASTER strip views |
| `ClearlyTextView.swift` | 361 | NSTextView subclass: custom cursor, keyboard shortcuts, spell-check |
| `MasterFolderModel.swift` | 283 | File management for `~/TextMD/MASTER/` folder |
| `TextEditBrowser.swift` | 256 | File browser panel for TextEdit documents |
| `QuickCopyButtons.swift` | 168 | Quick copy slots (3 clipboard slots + date) with edit popover |
| `ScratchpadManager.swift` | 237 | Global scratchpad window manager |
| `PDFExporter.swift` | 212 | Export Markdown → PDF |
| `OutlineState.swift` | 188 | Document outline (heading extraction) |
| `ColumnRulerView.swift` | ~150 | Toggleable column ruler |
| `ScrollSyncRelay.swift` | ~120 | Scroll position sync between editor and preview |
| `PositionSync.swift` | ~100 | Scroll position persistence (ScrollBridge, ScrollPositionStore) |

### 6.4 Shared Module

Code shared between the main app and the QuickLook extension:

| File | Role |
|------|------|
| `MarkdownRenderer.swift` | Markdown → HTML conversion using cmark-gfm |
| `PreviewCSS.swift` | CSS stylesheet for the HTML preview |
| `FrontmatterSupport.swift` | YAML frontmatter parsing |
| `LocalImageSupport.swift` | Resolve local image paths in preview |
| `MermaidSupport.swift` | Mermaid diagram rendering support |

Resources: `katex.min.js`, `katex.min.css`, `mermaid.min.js`, KaTeX fonts (woff2).

### 6.5 QuickLook Extension

`ClearlyQuickLook/PreviewProvider.swift` — provides Markdown previews in Finder's
Quick Look. Shares the rendering pipeline with the main app via the `Shared` module.

### 6.6 Window Layout

```
┌─────────────────────────────────────────────────┐
│ 🔴🟡🟢  Untitled — Edited                      │ ← Native title bar
├─────────────────────────────────────────────────┤
│  ✏️ ⬜ 👁  │ 📅 📋📋📋 ✎ │ ⊞ 📄 📁 ≡ 📏      │ ← Control bar (safeAreaInset)
├─────────────────────────────────────────────────┤
│ [Box palette]  (toggled via ⊞ button)           │
├─────────────────────────────────────────────────┤
│ [Column ruler] (toggled via 📏 button)          │
├─────────────────────────────────────────────────┤
│                                                 │
│  Editor / Split / Preview                       │ ← Main content area
│  (mode selected via ✏️/⬜/👁 buttons)           │
│                                                 │
├─────────────────────────────────────────────────┤
│ [MASTER strip] (toggled via 📄 button)          │
├─────────────────────────────────────────────────┤
│              24 words  142 characters           │ ← Status bar
├───────────────────────────┬─────────────────────┤
│ [Outline panel]           │ [TextEdit browser]  │
│ (toggled via ≡)           │ (toggled via 📁)    │
└───────────────────────────┴─────────────────────┘
```

### 6.7 Title Bar Subtitle Suppression

The native `DocumentGroup` + `unifiedCompact` toolbar style shows the document's
"Edited" status as a subtitle on a second line. To keep a single-line title bar,
`WindowActivator` (an `NSViewRepresentable`) uses KVO to observe `NSWindow.subtitle`
and clears it whenever macOS sets it:

```swift
context.coordinator.observation = window.observe(\.subtitle) { win, _ in
    if !win.subtitle.isEmpty {
        DispatchQueue.main.async { win.subtitle = "" }
    }
}
```

This forces macOS to render "Untitled — Edited" inline instead of stacked.

---

## 7. Mono Zen Color Palette

The syntax highlighting theme for the edit view. All colors are defined in
`Theme.swift` using `NSColor(name:provider:)` for automatic light/dark adaptation.

### Dark Mode (primary)

| Element        | Color         | Hex       | RGB (sRGB)              |
|----------------|---------------|-----------|-------------------------|
| Background     | Near-black    | `#1C1C1B` | `0.110, 0.110, 0.106`   |
| Body text      | White         | `#FFFFFF` | `1.0, 1.0, 1.0`         |
| Heading 1      | Stone gray    | `#D3D1C7` | `0.827, 0.820, 0.780`   |
| Heading 2      | Stone gray    | `#B4B2A9` | `0.706, 0.698, 0.663`   |
| Heading 3+     | Stone gray    | `#888780` | `0.533, 0.529, 0.502`   |
| Bold           | Gold          | `#C9A55A` | `0.788, 0.647, 0.353`   |
| Italic         | Sage green    | `#7A9E8A` | `0.478, 0.620, 0.541`   |
| Links          | Slate blue    | `#7B8FA1` | `0.482, 0.561, 0.631`   |
| Inline code    | Soft red      | `#C07070` | `0.753, 0.439, 0.439`   |
| Code background| Dark stone    | `#2C2C2A` | `0.173, 0.173, 0.165`   |
| Blockquotes    | Bronze        | `#8A7E6B` | `0.541, 0.494, 0.420`   |
| Strikethrough  | Dark stone    | `#5F5E5A` | `0.373, 0.369, 0.353`   |
| Syntax markers | Muted gray    | —         | `0.40, 0.40, 0.38`      |

### Syntax Highlighting Pipeline

1. `MarkdownSyntaxHighlighter.highlightAll()` resets the entire `NSTextStorage`
   to base font + white text color
2. Regex patterns run in order: frontmatter → fenced code → math → headings →
   bold → italic → strikethrough → inline code → links → blockquotes → list
   markers → horizontal rules
3. Protected ranges (code blocks, math blocks, frontmatter) are tracked to
   prevent inner patterns from overwriting them
4. Bold uses `NSColor(srgbRed:...)` for accurate gold rendering across
   wide-gamut and standard displays

### Regex Ordering Note

The italic regex uses negative lookahead/lookbehind for `*` to prevent matching
inside `**bold**` markers: `(?<![\\w*])(\\*|_)(?![\\s*])(.+?)(?<![\\s*])\\1(?![\\w*])`.
This is critical — without it, the italic pattern overwrites bold's gold color
with sage green.

---

## 8. Key UI Components

### 8.1 Control Bar

A horizontal strip below the title bar, always visible. Defined as a
`safeAreaInset(edge: .top)` in `ContentView.swift`.

Layout (right-aligned via leading `Spacer()`):

```
[Spacer] [edit] [split] [preview] | [date] [slot1] [slot2] [slot3] [edit-clips] | [grid] [doc] [folder] [outline] [ruler]
```

All buttons use `controlBarButton()` helper: 22x20 frame, `.plain` style,
11pt SF Symbols, accent color when active, `.secondary` when inactive.

### 8.2 Quick Copy Slots

Three clipboard slots + a date stamp button. Defined in `QuickCopyButtons.swift`.

- **Model**: `QuickCopyModel` — stores items in `UserDefaults` as JSON
  (key: `kindasQuickCopyItems_v2`)
- **UI**: all three slots use `square.on.square` icon; accent color when filled,
  `.secondary` when empty
- **Edit panel**: popover with `TextField(.roundedBorder)` per slot, direct
  `Binding` to model (no intermediate state)
- **Labels**: fixed "Slot 1/2/3" (not stored in the model's label field)

### 8.3 Box Character Palette

41×5 grid of special characters (box drawing, math symbols, arrows, etc.).
Toggle via `square.grid.3x3` button. Characters are clickable to insert into
the editor. Character foreground: `.secondary` (soft gray, not accent color).

### 8.4 Column Ruler

`ColumnRulerView.swift` — a horizontal ruler showing column positions.
Toggled via the ruler button. Default state: **off** (`rulerVisible = false`).

---

## 9. Working Directory Conventions

| Path | Purpose |
|------|---------|
| `~/TextMD/` | Default directory for new Markdown documents (created as `TX-YYYYMMDD-HHMMSS.md`) |
| `~/TextMD/MASTER/` | Reference notes, always accessible via the MASTER strip |
| `~/MBP-Mods/KindasMD/` | Project root (source of truth) |

---

## 10. Rebuilding From Scratch

### 10.1 From GitHub (clean machine)

```bash
# 1. Install prerequisites
xcode-select --install
brew install xcodegen

# 2. Clone
git clone https://github.com/kindashub/KindasMD.git
cd KindasMD

# 3. Build
bash System/build.sh

# 4. Create working directories
mkdir -p ~/TextMD/MASTER

# 5. Set as default Markdown editor (optional)
# The build script does this automatically if duti is installed:
# brew install duti && duti -s com.kindasmd.editor net.daringfireball.markdown editor

# 6. Drag KindasMD.app to your Dock
```

### 10.2 From Archive

If you have a `_archive/KindasMD-V*.tar.gz`:

```bash
mkdir KindasMD && cd KindasMD
tar xzf /path/to/KindasMD-V2.3-MonoZen_*.tar.gz
bash System/build.sh
```

### 10.3 Verifying the Build

```bash
# Check it's a real Swift app (not a Script Editor applet)
bash System/scripts/verify-kindasmd-editor.sh

# Check code signature
codesign -vvv System/app/KindasMDEditor.app
```

---

## 11. Common Issues

### App Crashes on Launch: "Taskgated Invalid Signature"

**Cause**: `cp -R` invalidates the ad-hoc code signature.
**Fix**: `build.sh` includes `codesign --force --deep --sign -` after copying.
If you manually copy the `.app`, re-sign it:
```bash
codesign --force --deep --sign - System/app/KindasMDEditor.app
```

### Double-Click .md Opens Wrong Build

**Cause**: macOS Launch Services has stale registrations from DerivedData builds.
**Fix**: `bash System/scripts/purge-stale-kindasmd.sh`

### Title Bar Shows Two Lines

**Cause**: `unifiedCompact` stacks title + "Edited" subtitle vertically.
**Fix**: `WindowActivator` uses KVO to clear `window.subtitle` (see Section 6.7).

### Bold Text Appears Green Instead of Gold

**Cause**: Italic regex `*...*` matches inside `**bold**` markers, overwriting
the gold color with sage green.
**Fix**: Italic regex includes `(?![\\s*])` negative lookahead to reject `*`
adjacent to another `*`.

---

## 12. Version History

| Version | Date | Highlights |
|---------|------|------------|
| V1.x | 2025 | Original build (archived in `_archive/KindasMD-V1-Archived.tar.gz`) |
| V2.0 | 2026-03 | Full rewrite: SwiftUI + AppKit, DocumentGroup, scroll sync, character palette |
| V2.1 | 2026-04 | Typography, UI overhaul, Quick Copy, TextEdit browser |
| V2.2 | 2026-04 | Read-only viewer, session handoff system |
| V2.3 | 2026-04 | Mono Zen palette, single-line title bar, toolbar cleanup, regex fixes |

---

## 13. License & Ownership

Private repository. All rights reserved by the project owner.
GitHub organization: [kindashub](https://github.com/kindashub).
