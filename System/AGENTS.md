# KindasMD — Agent Context

macOS Markdown editor. Swift/SwiftUI/AppKit. Sources: `src/editor/Clearly/`.

## Start Here

Read `README.md` in this folder. It is the single entry point for all agents.
README contains master rules, pipeline rules, operating procedures, and folder structure.

## Build

```bash
bash build.sh
```

Then Dock-launch `KindasMD.app` to verify.

## Architecture

Two `.app` bundles:
- `KindasMD.app` — Dock launcher (calls `system/kindasmd` script, creates TX-*.md, opens editor)
- `KindasMDEditor.app` — the editor (built from `src/editor/`)

Window layout: toolbar + optional box palette + optional column ruler +
editor/split/preview pane + optional MASTER strip + status bar + optional outline panel.

Core files:
- `ContentView.swift` — main layout, mode switching, toolbar
- `EditorView.swift` — NSTextView wrapper, scroll sync, find
- `PreviewView.swift` — WKWebView wrapper, HTML render, scroll sync
- `Theme.swift` — colors, fonts, spacing constants
- `KindasStripView.swift` — box character palette + MASTER strip views
- `PositionSync.swift` — scroll position storage (ScrollBridge, ScrollPositionStore)

Key pattern: NSTextView bridged to SwiftUI via NSViewRepresentable (not TextEditor).
This is intentional for undo, find panel, and NSTextStorageDelegate syntax highlighting.

## Pipeline Reminder

When ending a session, the cold-start message must appear in **both**:
1. The handoff file (`handoffs/YYYYMMDD-HHMMSS-sessionN.md`)
2. **The final chat response** (so the user can copy-paste it immediately)

See `.cursor/rules/kindasmd-dock-workflow.mdc` for full pipeline rules.
