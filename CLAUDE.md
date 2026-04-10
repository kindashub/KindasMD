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
