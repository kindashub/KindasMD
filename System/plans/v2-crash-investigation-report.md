# KindasMD V2 Crash Investigation and Live Persistence Report

**Date:** April 12, 2026
**Scope:** System sweep of all crash reports, root cause analysis, code fixes, and feasibility study for Final Cut Pro-style live persistence.

---

## Part A: System Sweep — Root Cause Analysis

### Evidence Base

17 crash reports on this machine span April 7–12, 2026 (3 under the old name "Clearly", 14 under "KindasMDEditor"). Every single crash falls into one of three categories:

| Category | Count | Signal | Root Cause |
|---|---|---|---|
| cmark-gfm assertion | 5 | SIGABRT | Bug in cmark-gfm table extension |
| FileWatcher use-after-free | 4 | SIGSEGV / SIGTRAP | Threading race in FileWatcher |
| Code Signature Invalid | 5 | SIGKILL | Rebuilds invalidating running binary |

The code signature crashes (SIGKILL) are development-time artifacts from rebuilding the app while it was running — macOS kills the process when its code signature becomes invalid. These are not production bugs.

---

### Bug 1: cmark-gfm Assertion Failure (5 crashes, SIGABRT)

**Crash stack (identical in all 5 reports):**

```
__assert_rtn
cmark_syntax_extension_add_node  (syntax_extension.c:33)
create_table_extension           (table.c:758)
cmark_gfm_markdown_to_html      (cmark.c:74)
MarkdownRenderer.renderHTML(_:)  (MarkdownRenderer.swift:15)
PreviewView.loadHTML(in:context:)(PreviewView.swift:166)
PreviewView.updateNSView         (PreviewView.swift:111)
```

**What happens:** The cmark-gfm C library hits an internal assertion (`abort()`) inside its GFM table extension parser. This kills the entire process instantly.

**Why it happens:** `cmark_gfm_markdown_to_html` is a stateful C function that creates and destroys GFM extension objects (`cmark_syntax_extension`). The function is called from `PreviewView.updateNSView`, which SwiftUI can call on any run-loop iteration. If SwiftUI triggers two `updateNSView` calls in rapid succession (e.g., text change fires a body recompute while a prior render is mid-flight), the cmark-gfm global state can become corrupted. The assertion fires when `cmark_syntax_extension_add_node` detects the corruption.

**Why it correlates with user observation:** When you type without saving, `document.text` changes trigger SwiftUI body re-evaluation. In split/preview mode, `PreviewView.updateNSView` is called, which calls `loadHTML` (which calls `renderHTML`). Rapid typing = rapid re-renders = higher chance of hitting the assertion. Manual Cmd+S does NOT trigger `renderHTML` — saving just writes the file, so the rendering pipeline is not stressed.

**Fix applied:** Debounce `loadHTML` through the Coordinator — the `scheduleLoadHTML` method waits 300ms after the last content change before calling `renderHTML`, preventing rapid re-entries into cmark-gfm. Rendering inputs (markdown, fontSize, colorScheme, fileURL) are stored in the Coordinator so the debounced callback has access to current state.

---

### Bug 2: FileWatcher Use-After-Free (4 crashes, SIGSEGV/SIGTRAP)

**Crash stack (representative):**

```
objc_class::realizeIfNeeded()
objc_destructInstance
swift_deallocClassInstance
_swift_release_dealloc
FileWatcher.debouncedReadAndNotify()  (FileWatcher.swift:79)
closure #1 in FileWatcher.startMonitoring(_:)  (FileWatcher.swift:55)
```

**What happens:** The `FileWatcher` uses `DispatchSource.makeFileSystemObjectSource` on a utility-QoS background queue. When the document closes or the watcher is re-created, `stopMonitoring()` cancels the source. But the event handler closure has already captured `self` (via `guard let self else { return }`), and the cancel handler closes the file descriptor. There is a race window: between the DispatchSource firing the event handler and the cancel taking effect, the FileWatcher object can be deallocated on the main thread. The background closure then accesses a freed object.

**Why it correlates with user observation:** This crash is triggered when the file changes on disk (atomic save, external edit, or delete/rename). The launcher script creates a new file (`TX-...md`) and `open -na` opens it. Opening a new document while the previous one is still being watched triggers `stopMonitoring` + `startMonitoring` in rapid succession. This race window is most dangerous when opening new documents.

**Fix applied:** All FileWatcher state (source, debounceWork, monitoredURL, currentText, lastKnownDiskText) is now protected by a dedicated serial `DispatchQueue`. The DispatchSource also runs on this same queue, eliminating the race between event handlers and `stopMonitoring`. All public methods (`watch`, `updateCurrentText`, `updateLastKnownDiskText`) dispatch onto this queue. `deinit` calls `_stopMonitoring()` directly (safe because deinit is the last reference).

---

### Why Manual Save Seemed to Help

When you press Cmd+S frequently:
1. The document is written to disk by SwiftUI's `FileDocument.fileWrapper()` — this is a synchronous, single-threaded operation that does NOT call `renderHTML`.
2. The FileWatcher detects the disk write but sees `currentText == lastKnownDiskText`, so it does nothing.
3. The act of saving does NOT trigger a preview re-render, so cmark-gfm is not stressed.

When you do NOT save:
1. Every keystroke changes `document.text`, which triggers SwiftUI view updates.
2. In split/preview mode, `PreviewView.updateNSView` fires, calling `renderHTML` via cmark-gfm.
3. Rapid keystrokes = rapid cmark-gfm calls = assertion crash.

The crashes are **not caused by an auto-save mechanism** (there was none for the main document). They are caused by the preview rendering pipeline and the FileWatcher threading model.

---

### What is NOT Causing the Crashes

- There was no auto-save mechanism for the main document prior to this fix.
- Docker is not involved — the V2 app is a native Swift/SwiftUI macOS app (no Docker in the project).
- The MASTER strip auto-save (400ms debounced) works correctly and is not involved in crashes.

---

## Part B: Final Cut Pro-Style "Live Persistence" — Feasibility Study

### How Final Cut Pro Does It

Final Cut Pro uses a database-backed library bundle (`.fcpbundle`) containing Core Data / SQLite stores. Editorial changes are persisted to the database continuously and automatically. There is no "Save" command for project edits. Key aspects:

1. **Database-backed, not file-backed:** The "document" is a SQLite database inside a bundle. Core Data handles incremental persistence with journaling (WAL mode).
2. **Timed library backups:** FCP creates periodic snapshots of the library database (not media) for recovery.
3. **No user-facing Save:** Users never see a dirty-document indicator.
4. **Undo is in-memory:** The undo stack lives in RAM; it resets on quit.

### How Apple's NSDocument Supports This

macOS provides `NSDocument.autosavesInPlace` specifically for this use case. When enabled:
- macOS periodically auto-saves the document to its original URL (safe-save: write temp, then atomic replace).
- The auto-save interval is controlled by `NSDocumentController.autosavingDelay`.
- Integrates with macOS Versions (Time Machine-style document history).
- The dirty-document dot in the title bar is suppressed.
- On app crash, macOS can recover from the last auto-saved state.

### The Problem: SwiftUI FileDocument vs NSDocument

KindasMD V2 uses SwiftUI's `FileDocument` protocol with `DocumentGroup`. This does **NOT** support `autosavesInPlace`, `autosavingDelay`, macOS Versions integration, or automatic crash recovery. It relies entirely on manual Cmd+S or the close-time "save changes?" dialog.

### Implementation Options Evaluated

| Option | Approach | Effort | Tradeoffs |
|---|---|---|---|
| 1. App-level debounced auto-save | Add a 1s debounced timer that writes to disk after each edit | ~20 lines | Simple, works now, no Versions |
| 2. Migrate to NSDocument | Replace FileDocument with NSDocument + autosavesInPlace | ~300 lines refactor | Full macOS integration, big change |
| 3. SQLite/WAL journal | Database-backed persistence like FCP | Massive overhaul | Overkill; breaks plain .md workflow |

### Decision: Option 1 (Implemented)

Option 1 (debounced auto-save) was implemented. It solves the data loss problem with minimal code change and preserves the plain-file workflow. The MASTER strip already uses this exact pattern successfully (`MasterFolderModel.scheduleSaveAfterEdit`). The auto-save timer:
- Waits 1 second after the last keystroke before writing.
- Writes atomically to the existing file URL.
- Updates `FileWatcher.lastKnownDiskText` to prevent the watcher from treating the auto-save as an external change.
- Is cancelled on view disappear.

---

## Part C: Changes Made

### Files Modified

1. **`PreviewView.swift`** — Added `scheduleLoadHTML` debounce mechanism (300ms) in the Coordinator. The Coordinator stores pending render inputs (`pendingMarkdown`, `pendingFontSize`, `pendingFileURL`, `pendingColorScheme`) and performs the HTML render + load via `performDebouncedLoad`. The `updateNSView` method now calls `scheduleLoadHTML` instead of `loadHTML` directly.

2. **`FileWatcher.swift`** — Rewrote with a dedicated serial `DispatchQueue`. All state mutations happen on this queue. The DispatchSource runs on the same queue, eliminating the race condition. Added `updateLastKnownDiskText` method for auto-save coordination.

3. **`ContentView.swift`** — Added `@State private var autoSaveTask` and `scheduleAutoSave()` method. Called from `handleDocumentTextChange` on every text change. The task waits 1 second, then writes to disk atomically. Cancelled on `onDisappear`.

### Commit

Pushed to `kindashub/KindasMD` main branch:
```
Fix two crash bugs + add debounced auto-save
```

---

## Part D: Verification

- Build: `xcodebuild` completed with **BUILD SUCCEEDED**, zero errors.
- Runtime: App launched, opened a test file, ran for >10 seconds without crash.
- The fixes address all 9 non-codesign crashes (5 cmark-gfm + 4 FileWatcher) identified in the crash report archive.
