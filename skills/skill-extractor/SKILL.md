---
name: skill-extractor
description: Automatically extract reusable knowledge from work sessions and save as new Claude Code skills. Use when encountering non-obvious solutions, project-specific patterns, debugging workarounds, or workflow discoveries that would help in future tasks. Trigger with "extract a skill from this", "save this as a skill", "what did we learn?", or after any task involving trial-and-error discovery.
---

# Skill Extractor

Continuously learn from work sessions by extracting reusable knowledge into Claude Code skills.

## When to Extract

Extract a skill when you encounter:
- A **non-obvious solution** that required debugging or trial-and-error
- A **project-specific pattern** that will recur
- **Tool integration knowledge** (API quirks, config gotchas, undocumented behavior)
- **Error resolutions** that were hard to figure out
- **Workflow optimizations** discovered during a task

## When NOT to Extract

Do NOT extract if the knowledge is:
- Already in official documentation (just link to it)
- Obvious or trivial
- One-time / non-reusable
- Not verified to actually work
- Too broad to be actionable

## Extraction Process

### Step 1: Check for Duplicates

```bash
# Check existing skills
ls ~/.claude/skills/ .claude/skills/ 2>/dev/null
```

Search existing skill descriptions for overlap. If a similar skill exists, update it instead of creating a new one.

### Step 2: Identify the Knowledge

Answer these questions:
- **What was the problem?** (specific, reproducible)
- **What was the non-obvious part?** (what took effort to discover)
- **What is the solution?** (concrete steps)
- **When does this apply?** (trigger conditions)
- **How do I verify it works?** (test/check)

### Step 3: Structure the Skill

Create `SKILL.md` with this template:

```markdown
---
name: [lowercase-hyphenated-name]
description: [What it does and when to use it. Include specific trigger keywords.]
---

# [Skill Name]

## Problem
[What goes wrong / what's hard to do without this knowledge]

## Context
[When this applies — frameworks, versions, conditions]

## Solution
[Step-by-step concrete instructions]

## Verification
[How to confirm the solution works]

## Example
[Before/after or concrete usage example]

## Notes
- [Edge cases, limitations, related issues]

## References
- [Links to relevant docs, issues, or discussions]
```

### Step 4: Write an Effective Description

The `description` field determines when the skill triggers. It must:
- State **what** the skill does (first clause)
- State **when** to use it (second clause, with specific keywords)
- Include terms users would naturally say
- Be under 1024 characters

Good: `"Fix PostgreSQL connection pool exhaustion in SQLAlchemy. Use when seeing 'QueuePool limit overflow' errors, connection timeouts, or when configuring SQLAlchemy engine pool settings."`

Bad: `"Database connection helper"` (too vague, won't trigger correctly)

### Step 5: Save the Skill

Choose the scope:

| Scope | Location | Use Case |
|-------|----------|----------|
| Project | `.claude/skills/[name]/SKILL.md` | Team knowledge, project-specific |
| Personal | `~/.claude/skills/[name]/SKILL.md` | Cross-project personal knowledge |

### Step 6: Verify Activation

Test with a prompt that should trigger the skill. Confirm it activates and provides useful guidance.

## Skill Lifecycle

| Version Bump | When |
|-------------|------|
| Patch (0.0.x) | Fix typos, clarify wording |
| Minor (0.x.0) | Add new patterns, examples, or sections |
| Major (x.0.0) | Fundamental approach change |

When updating an existing skill:
1. Read the current SKILL.md
2. Add new knowledge without removing verified existing content
3. Update version in frontmatter if present
4. Add a note about what changed

## Quality Checklist

Before saving a new skill, verify:

- [ ] The knowledge is **non-obvious** (required real discovery)
- [ ] The solution is **verified** (actually tested and working)
- [ ] The description is **specific** enough to trigger correctly
- [ ] The content is **actionable** (not just theory)
- [ ] No duplicate skill exists
- [ ] Includes a concrete **example**
- [ ] Trigger keywords match how users naturally describe the problem
