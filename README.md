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
