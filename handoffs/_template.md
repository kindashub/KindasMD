# Session Handoff: [SESSION_NAME]

**Date:** YYYY-MM-DD
**Session:** N of N (Plan: [plan filename])
**Commit:** [hash]

## What Was Done

- (bullet list of completed work, specific and concrete)

## What Was NOT Done / Deferred

- (anything from the plan that was skipped or deferred, and why)

## Current State

- Build: passing / failing
- Code: [brief state]
- Repo: https://github.com/kindashub/KindasMD at commit [hash]

## What To Do Next

- (specific, actionable next steps — taken directly from the plan)
- Reference: `plans/[plan-filename].md`, SESSION N+1

## Cold-Start Message

Copy this exactly into the next session. All four fields are required.

```
Read ~/MBP-Mods/KindasMD/README.md -- it tells you everything.
Check handoffs/ for the latest session note.
The active plan is at plans/[exact-plan-filename].md.
You are starting Session N+1: [session name from plan].

Your task: [exact task description from the plan's SESSION N+1 section].
Key files: [list the files the plan says to touch].
```

---

## Pipeline Check (fill before closing this handoff)

- [ ] Plan file exists at `plans/[name].md` and is committed
- [ ] Cold-start above names the plan file explicitly
- [ ] Cold-start above names the next session and task explicitly
- [ ] All code changes are committed and pushed
- [ ] Build passes (`bash build.sh`)
