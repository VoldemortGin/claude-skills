---
name: persistent-planning
description: File-based persistent planning for complex multi-step tasks. Use when starting tasks requiring more than 5 tool calls, research projects, multi-file refactors, or any work spanning many steps. Creates task_plan.md, findings.md, and progress.md as working memory on disk to prevent context loss.
---

# Persistent Planning

Use the filesystem as persistent working memory for complex tasks. Prevents context loss in long sessions.

## Core Principle

```
Context Window = RAM (volatile, limited)
Filesystem     = Disk (persistent, unlimited)

→ Anything important gets written to disk immediately.
```

## When to Use

- Multi-step tasks (5+ tool calls)
- Research or exploration tasks
- Building/creating projects from scratch
- Tasks that may span session boundaries

Skip for: simple questions, single-file edits, quick lookups.

## Quick Start

Before ANY complex task, create three files in the **project directory**:

### 1. `task_plan.md`

```markdown
# Task Plan

## Goal
[One sentence: what are we trying to achieve?]

## Phases

### Phase 1: [Name]
- Status: pending | in_progress | complete
- Steps:
  - [ ] Step 1
  - [ ] Step 2
- Files touched: []
- Errors: []

### Phase 2: [Name]
...

## Decisions
| Decision | Rationale | Date |
|----------|-----------|------|

## Constraints
- [Known limitations or requirements]
```

### 2. `findings.md`

```markdown
# Findings

## Key Discoveries
- [Date] [Discovery and its implications]

## Code Patterns Found
- [Pattern]: [Where and how it's used]

## API/Library Notes
- [Library]: [Quirks, gotchas, working configs]

## Dead Ends
- [What was tried] → [Why it didn't work]
```

### 3. `progress.md`

```markdown
# Progress Log

## Current Session
- Started: [timestamp]
- Working on: [current phase]

## Log
- [timestamp] [What was done, what happened]

## Test Results
- [timestamp] [Test name]: pass/fail — [details]

## Files Modified
- [file path] — [what changed]
```

## Critical Rules

### 1. Plan First, Execute Second
Never start a complex task without creating `task_plan.md`. Non-negotiable.

### 2. The 2-Action Rule
After every 2 search/browse/read operations, IMMEDIATELY save key findings to `findings.md`. Don't wait — context can be lost.

### 3. Read Before Decide
Before any major decision, re-read `task_plan.md` to refresh goals in the attention window.

### 4. Update After Act
After completing any phase:
- Mark phase status: `in_progress` → `complete`
- Log errors encountered
- Note files created/modified in `progress.md`

### 5. Log ALL Errors
Every error goes into the plan file. Never silently retry.

### 6. Never Repeat Failures
Track what was tried. Mutate the approach on each retry.

## 3-Strike Error Protocol

```
Strike 1: Diagnose and fix directly
Strike 2: Try an alternative approach
Strike 3: Rethink the broader strategy
After 3 failures: Escalate to user with full context
```

## Read vs Write Decision Matrix

| Situation | Action | Reason |
|-----------|--------|--------|
| Just wrote a file | Don't read it back | Content still in context |
| Viewed image/PDF | Write findings NOW | Multimodal content doesn't persist as text |
| Browser returned data | Write to findings.md | Screenshots/HTML don't persist |
| Starting new phase | Read plan + findings | Re-orient if context is stale |
| Error occurred | Read relevant plan section | Need current state to debug |
| Resuming after break | Read all three files | Full state recovery |

## 5-Question Reboot Test

When disoriented, answer these from the planning files:

| Question | Source |
|----------|--------|
| Where am I? | Current phase in task_plan.md |
| Where am I going? | Remaining phases |
| What's the goal? | Goal statement in plan |
| What have I learned? | findings.md |
| What have I done? | progress.md |

## Anti-Patterns

| Don't | Do Instead |
|-------|------------|
| State goals once and forget | Re-read plan before decisions |
| Hide errors and retry silently | Log errors to plan file |
| Stuff everything in context window | Store large content in files |
| Start executing immediately | Create plan file FIRST |
| Repeat the same failed action | Track attempts, change approach |
| Keep findings only in memory | Write to findings.md after every 2 actions |
