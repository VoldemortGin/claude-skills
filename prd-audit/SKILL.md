---
name: prd-audit
description: >
  PRD status audit — scan the codebase, compare against existing PRD, and produce a structured
  feature inventory with implementation status. Optionally captures app screenshots to embed in
  the document. Use when user says /prd, "盘点PRD", "PRD现状", "feature audit",
  "功能盘点", "更新PRD", or asks to review what's done vs pending.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, AskUserQuestion
---

# PRD Status Audit Skill

Produce or update a structured PRD document that inventories every feature area of the project,
marks each item as implemented / partial / pending, and optionally embeds UI screenshots.

## Status markers

Use these markers at the start of each line:

- `[x]` — Fully implemented and working
- `[~]` — Partially implemented (note what's missing)
- `[ ]` — Not yet implemented / planned

## Workflow

### Phase 1 — Discover existing PRD

1. Look for an existing PRD file. Common locations:
   - `docs/PRD.md`
   - `PRD.md`
   - `docs/prd.md`
2. If found, read it and use it as the baseline structure.
3. If not found, ask the user where to create one (default: `docs/PRD.md`).

### Phase 2 — Codebase scan

Use the **Explore** subagent (Task tool, subagent_type=Explore) to comprehensively scan the project.
The scan should cover:

#### Backend / Core layer
- Data models and schemas
- API surface / FFI interface — list every public function
- Business logic modules
- Cryptography / security
- Database operations
- Import/export formats
- Tests (unit, integration)

#### Frontend / UI layer
- Every view / screen / page — describe its purpose
- Navigation structure (tabs, sidebar, split view, etc.)
- Platform-specific adaptations (#if os, responsive layout, etc.)
- Sheets, modals, alerts
- Reusable components

#### Services / Infrastructure
- Network services, caching, persistence
- Authentication / biometrics
- Clipboard, notifications, background tasks
- Browser extensions, plugins
- Build system, CI/CD, deployment

#### Cross-cutting
- Accessibility
- Localization / i18n
- Error handling patterns
- Test coverage

For each item found, determine: **fully done**, **partial** (note gaps), or **missing/planned**.

### Phase 3 — Optional screenshot capture

Ask the user:

> 需要截图吗? 可以自动截取 macOS 窗口和 iOS 模拟器界面嵌入到 PRD 中。

If yes, capture screenshots using the companion skills:

#### macOS screenshots (mac-screenshot)

Build and launch the macOS app, then use the mac-screenshot recipe format:

```bash
bash /Users/linhan/.claude/skills/mac-screenshot/scripts/mac_screenshot.sh \
  --app-name "<AppName>" \
  --output-dir docs/screenshots \
  <<'EOF'
ACTIVATE
WAIT 2
RESIZE 1200 800
SCREENSHOT main_window.png
# Navigate to different views and capture each
SIDEBAR <sidebar_item>
WAIT 1.5
SCREENSHOT <view_name>.png
EOF
```

Capture key screens:
- Main window / default state
- Each major navigation section (sidebar items, tabs)
- Key feature screens (settings, generators, security checks, etc.)
- Both light and dark mode if relevant

#### iOS screenshots (sim-screenshot)

If an iOS simulator is booted with the app running:

```bash
xcrun simctl io booted screenshot docs/screenshots/ios_<view_name>.png
```

Navigate the app between captures (may require user interaction for navigation,
or use the app's deep linking / state manipulation).

Capture key screens:
- Each tab in the tab bar
- Detail views
- Modal sheets (settings, forms)

#### Embed in PRD

Reference screenshots in the PRD using relative paths:

```markdown
### 2.2 Main Interface
![Main Window](screenshots/main_window.png)
- [x] Three-column NavigationSplitView
```

### Phase 4 — Generate / update PRD

Structure the PRD document with these conventions:

1. **Title** with project name + "PRD — Feature Status Audit"
2. **Legend** explaining `[x]`, `[~]`, `[ ]` markers
3. **Last updated** date
4. **Sections** organized by architectural layer:
   - Core / Backend
   - Desktop client (macOS)
   - Mobile client (iOS / iPhone)
   - Tablet client (iPad) — if applicable
   - Browser extensions — if applicable
   - Build & deployment
   - Testing
   - Future / planned features
5. Within each section, use **subsections** for feature areas
6. Each feature is one bullet with a status marker
7. Partial items `[~]` include a parenthetical note explaining what's missing
8. At the end, a **Summary table** with counts per section:

```markdown
| Area | Done | Partial | Pending |
|------|------|---------|---------|
| Core | 28   | 1       | 3       |
| ...  |      |         |         |
```

### Phase 5 — Diff report (if updating)

If an existing PRD was found, after generating the updated version:

1. Show a brief summary of what changed:
   - Items that moved from `[ ]` to `[x]` (newly completed)
   - Items that moved from `[ ]` to `[~]` (in progress)
   - New items added
   - Items removed
2. Ask user to confirm before writing the file.

## Tips

- Use parallel subagents to scan different layers simultaneously (Rust core, Swift views, services, etc.)
- For large codebases, focus the Explore agent on public API surfaces rather than implementation details
- When in doubt about implementation completeness, check for TODO/FIXME/HACK comments
- Cross-reference: if a Rust FFI function exists but no Swift code calls it, mark Swift-side as `[ ]`
- The PRD should be useful to a new developer joining the project — clear, factual, no marketing language
