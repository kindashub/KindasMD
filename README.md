# KindasMD

A macOS Markdown editor. Swift / SwiftUI / AppKit.

---

## For Agents: Read This First

This README is your complete operating guide. If you were told "read the README" — this is it.
Read it fully before doing anything.

---

## Master Rules

**Rule 1 — Understand before acting:**
"Understand the whole, then change the smallest correct thing. Before acting, you must be
able to describe the system's purpose, constraints, and relationships completely. If an
assumption could break the result, you are not ready. When acting, make the smallest change
that reaches the root cause. Every element must earn its place."

**Rule 2 — Always hand off:**
After EVERY session (completion, hard stop, or interruption), you MUST:
1. Write a handoff note to `handoffs/YYYYMMDD-HHMMSS-sessionN.md` using the template
2. Commit and push all changes
3. Give the user a COPYABLE cold-start for the next agent

The cold-start MUST follow this exact format — every field is required:

```
Read ~/MBP-Mods/KindasMD/README.md -- it tells you everything.
Check handoffs/ for the latest session note.
The active plan is at plans/[exact-filename].md.
You are starting Session N: [session name].

Your task: [exact task from the plan's SESSION N section].
```

**Rule 3 — Plans live in `plans/` only:**
See the Pipeline section below. This is the most common point of failure.

---

## Pipeline: How Plans, Sessions, and Handoffs Flow

This is the most important section. Pipeline failures cause agents to work without a plan,
implement wrong things, and leave the project in bad state.

### The Flow

```
1. PLAN CREATION
   A plan is created (or updated) for a body of work.
   → It is written to plans/[name].md  ← THE ONLY VALID LOCATION
   → It is committed and pushed immediately

2. SESSION START
   Agent reads README (this file) → reads latest handoff → reads the plan
   Cold-start message always names the plan file explicitly.

3. SESSION WORK
   Agent follows the plan section for this session.
   Agent does NOT improvise tasks not in the plan.

4. SESSION END
   Agent writes handoff to handoffs/ (using the template)
   Handoff cold-start names: the plan file + next session + exact task
   Agent commits, pushes, gives user the cold-start.

5. NEXT SESSION
   User pastes cold-start → agent reads README → reads handoff → reads plan → works
```

### Plan Rules (Critical)

- **Plans MUST be in `plans/` inside this project folder.** Always. No exceptions.
- **NEVER create plans in `.cursor/plans/`.** That folder uses UUID filenames and is
  invisible to agents following the README workflow. This is the #1 pipeline failure.
- **NEVER create plans in any other hidden or IDE-specific folder.**
- When a plan is first created (e.g., by a planning session), the very first action is
  to save it to `plans/[descriptive-name].md` and commit it. If you created a plan and
  it is not in `plans/` yet — stop and move it there before anything else.
- The active plan is always named in the latest handoff's cold-start.
- If no handoff exists yet for a plan, the plan file itself contains the cold-start
  (see SESSION 0 / Pre-Work sections).

### Finding the Active Plan

1. Read the latest handoff in `handoffs/` (sorted by filename, newest = largest timestamp).
2. The cold-start section names the plan file: `plans/[name].md`.
3. If the latest handoff has no plan reference, read ALL files in `plans/` and ask the
   user which is active. Do NOT guess. Do NOT start work without a plan.

### If You Are Asked to Create a Plan

1. Create it as `plans/[descriptive-name].md` (e.g., `plans/v2.1-refinement-plan.md`).
2. Commit it immediately: `git add plans/ && git commit -m "Add plan: [name]" && git push`
3. Write a handoff that references it, with a cold-start in the required format.
4. Give the user the cold-start so the next session can find it.

---

## Operating Procedures

1. Read this README (you are doing this now)
2. Read `AGENTS.md` for architecture and technical context
3. Read the latest handoff in `handoffs/` for current state
4. Read the active plan in `plans/` for your session's tasks
5. Build: `bash build.sh` (then Dock-launch `KindasMD.app` to verify)
6. Do the work, following the plan section for your session exactly
7. After work: write handoff, commit, push, give user the cold-start

---

## Source of Truth (SOT)

This folder (`~/MBP-Mods/KindasMD/`) is the source of truth.
Everything needed to understand, build, and extend KindasMD lives here.

---

## GitHub Sync

Repo: `https://github.com/kindashub/KindasMD` (separate from MBP-Mods)

- The SOT folder is primary. The repo is a backup/sync target.
- After every session that changes code or docs, commit and push:
  `git add -A && git commit -m "description" && git push`
- The repo must always reflect the current SOT state.
- If this machine is lost: clone the repo, then `bash build.sh`.

---

## Folder Structure

```
KindasMD/
├── README.md              ← YOU ARE HERE. Single entry point for all agents.
├── AGENTS.md              ← Architecture and technical context (agent-agnostic)
├── CHANGELOG.md           ← Running changelog
├── build.sh               ← One-command build + install
│
├── plans/                 ← ALL plans live here. NEVER in .cursor/plans/
│   ├── v2-build-plan.md   ← V2 build plan (completed)
│   └── v2.1-refinement-plan.md ← V2.1 refinement plan (active)
│
├── handoffs/              ← Session handoff notes (YYYYMMDD-HHMMSS-sessionN.md)
│   └── _template.md       ← Template for all handoffs
│
├── src/editor/Clearly/    ← Swift source files
├── src/editor/project.yml ← xcodegen project definition
├── system/                ← Dock launcher scripts
├── app/                   ← Installed .app bundles
└── _archive/              ← Compressed V1 (reference only, do not extract)
```

---

## Key Technical Facts

- Deployment target: macOS 14.0, Swift 5.9
- SPM deps: cmark-gfm (MD→HTML), KeyboardShortcuts
- Sandbox: DISABLED (required for `~/TextMD` file access)
- Build: `xcodegen generate` + `xcodebuild` (see `build.sh`)
- Launcher: `KindasMD.app` (Dock) → `system/kindasmd` → `open -na KindasMDEditor.app`
- The `-n` flag is critical: without it macOS reuses stale processes
- Working directory: `~/TextMD/` (new docs created here)
- MASTER notes: `~/TextMD/MASTER/`

---

## Do NOT

- **Do NOT put plans in `.cursor/plans/` or any hidden/IDE folder** — use `plans/` only
- **Do NOT start work without reading the active plan** — find it first
- **Do NOT write a cold-start without the plan filename** — it breaks the next session
- Do NOT force-push or rewrite git history
- Do NOT casually refactor the HSplitView block in `ContentView.swift`
- Do NOT add Sparkle or any auto-update framework
- Do NOT skip the handoff note at session end
- Do NOT name context files after specific AI products (`CLAUDE.md`, `GPT.md`, etc.)
  — use `AGENTS.md` which works for any agent
