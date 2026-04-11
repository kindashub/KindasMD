# Changelog

All notable changes to KindasMD.

## V2.3 — Mono Zen (2026-04-11)

- **Mono Zen color palette**: custom syntax highlighting theme with per-element
  colors — gold bold, sage green italic, slate blue links, soft red code,
  bronze blockquotes, stone gray headings (3 levels), dark stone strikethrough
- **Per-level heading colors**: H1 (#D3D1C7), H2 (#B4B2A9), H3+ (#888780)
- **Code background**: inline code and fenced code blocks get a subtle dark
  background (#2C2C2A)
- **Single-line title bar**: KVO observer suppresses macOS "Edited" subtitle
  to keep title on one row
- **Toolbar cleanup**: removed chevron toggle, control bar always visible,
  no toolbar items in native title bar
- **Italic regex fix**: prevent italic pattern from overwriting bold colors
  by rejecting `*` adjacent to another `*`
- **Quick Copy slots**: fixed labels ("Slot 1/2/3"), consistent `square.on.square`
  icons, direct binding in edit panel
- **Character palette**: softened to `.secondary` foreground
- **Window defaults**: ruler off by default, 500x400 initial size, no frame
  persistence
- **Build handbook**: comprehensive docs for rebuilding from scratch

## V2.2 — Read-Only Viewer (2026-04)

- Read-only viewer window
- Remove buggy in-viewer file switching

## V2.1 — UI Polish (2026-04)

- Typography overhaul
- Quick Copy buttons (date + 3 clipboard slots)
- Box Palette expansion (41x5 grid)
- TextEdit File Browser panel
- Right-aligned toolbar buttons, flat mode picker

## V2.0 — Rewrite (2026-03)

- Full rewrite: SwiftUI + AppKit, DocumentGroup architecture
- Project restructure: self-contained repo with archived V1
- Foundation cleanup: removed Sparkle, pinned deps, guarded force-unwraps
- Scroll sync rewrite (line-number based)
- Crash prevention guards

## V1.x — Archived

See _archive/KindasMD-V1-Archived.tar.gz for full history.
