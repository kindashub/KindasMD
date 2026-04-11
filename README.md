# KindasMD

A native macOS Markdown editor built with Swift, SwiftUI, and AppKit.

---

## Quick Start

```bash
# Prerequisites: Xcode 16+, xcodegen (brew install xcodegen)
git clone https://github.com/kindashub/KindasMD.git
cd KindasMD
bash System/build.sh
# Drag KindasMD.app to your Dock
```

**Already built?** Just drag `KindasMD.app` to your Dock and click it.

---

## Documentation

| Document | Purpose |
|----------|---------|
| [`System/docs/HANDBOOK.md`](System/docs/HANDBOOK.md) | Complete build handbook — everything needed to rebuild from scratch |
| [`System/README.md`](System/README.md) | Agent operating guide + master rules |
| [`System/AGENTS.md`](System/AGENTS.md) | Architecture and technical context |
| [`System/CHANGELOG.md`](System/CHANGELOG.md) | Version history |

---

## Project Structure

```
KindasMD/
├── KindasMD.app          ← Dock launcher (click to open editor)
├── README.md             ← YOU ARE HERE
└── System/
    ├── docs/HANDBOOK.md  ← Full rebuild handbook
    ├── build.sh          ← One-command build + install
    ├── src/editor/       ← Swift source code (~5850 LOC)
    ├── scripts/          ← Dock launcher + utilities
    ├── plans/            ← Development plans
    └── handoffs/         ← Session handoff notes
```

---

## Current Version

**V2.3 "Mono Zen"** — April 2026

Features: live edit/split/preview, Mono Zen syntax colors, character palette,
Quick Copy clipboard slots, column ruler, document outline, MASTER notes,
scratchpad, PDF export, QuickLook extension.
