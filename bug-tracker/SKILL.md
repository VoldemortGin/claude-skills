---
name: bug-tracker
description: Record fixed bugs to docs/bugs/ with individual detail files and a summary index. Use when user says /bug, "record bug", "document this bug", "记录 bug", or after fixing a bug that should be documented to prevent recurrence.
user-invocable: true
invocation-name: bug
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Bug Tracker — Record & Prevent Recurrence

Record fixed bugs into a structured documentation folder so the same mistakes are never repeated. Claude should read these bug records at the start of relevant tasks to avoid known pitfalls.

## Trigger

- User invokes `/bug`
- User says "record this bug", "document this bug", "记录 bug", "记录这个问题"
- After fixing a bug, user wants to document it for future reference

## Workflow

### 1. Gather Bug Information

From the current conversation context, extract:
- **What happened** (现象): The observable symptom
- **Root cause** (根因): Why it happened
- **Fix** (修复方案): What was changed to fix it
- **Lessons / Gotchas** (注意事项): What to watch out for in the future
- **Files involved** (涉及文件): Which files were modified

If any information is unclear, ask the user for clarification.

### 2. Find or Create the Bugs Folder

- Default path: `docs/bugs/` relative to the project root (where `.git/` is)
- If the folder doesn't exist, create it
- If `docs/bugs/README.md` doesn't exist, create the initial index file

### 3. Determine Next Bug Number

- Scan existing files matching pattern `NNN-*.md` in the bugs folder
- Take the highest number and increment by 1
- Format as 3-digit zero-padded: `001`, `002`, `003`, ...

### 4. Create the Bug Detail File

Filename: `{NNN}-{short-slug}.md` (e.g., `003-config-yaml-not-bundled.md`)

Use this template:

```markdown
# BUG-{NNN}: {One-line title}

## 现象 (Symptom)

{What the user observed. Be specific — include error messages, UI behavior, etc.}

## 根因 (Root Cause)

{Why it happened. Trace the logic chain.}

## 修复方案 (Fix)

{What was changed. Include file names and a brief description of the change.}

## 注意事项 (Lessons & Gotchas)

- {Bullet points of things to remember to avoid this in the future}
- {Each point should be actionable and specific}

## 涉及文件 (Files)

- `path/to/file1`
- `path/to/file2`
```

### 5. Update the Summary Index

Update `docs/bugs/README.md`:

- Add a row to the index table for the new bug
- If there are new "通用注意事项" (general gotchas) from this bug, append them to the appropriate section

The README structure:

```markdown
# Bug 修复记录与注意事项

已修复的 bug 和从中总结的经验教训。

## 索引

| 编号 | 描述 | 涉及文件 |
|------|------|----------|
| [001](001-xxx.md) | Brief description | `file.rs` |
| [002](002-yyy.md) | Brief description | `file.swift` |

## 通用注意事项

### {Category 1} (e.g., SwiftUI, Rust, Build System)

- **Rule**: Explanation
- **Rule**: Explanation

### {Category 2}

- **Rule**: Explanation
```

### 6. Confirm to User

After creating the files, output:
- The bug number and title
- The file path of the detail document
- Any new general gotchas that were added to the README

## Important Rules

- **Language**: Match the user's language. If the conversation is in Chinese, write in Chinese. If English, write in English. The template section headers (现象, 根因, etc.) stay bilingual.
- **Be concise**: Bug documents should be scannable, not essays. Use bullet points.
- **Actionable gotchas**: Each "注意事项" should be something Claude or a developer can act on, not a vague observation.
- **Dedup gotchas**: Before adding a new gotcha to the README's general section, check if a similar one already exists.
- **Slug naming**: Use lowercase English slugs separated by hyphens, max 5 words (e.g., `save-button-hidden`, `config-not-bundled`).
