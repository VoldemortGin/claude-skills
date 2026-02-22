# Claude Skills

A collection of custom Claude Code skills for daily development workflows.

## Installation

### Method 1: Plugin Marketplace (Recommended)

Register this repository as a plugin marketplace in Claude Code:

```
/plugin marketplace add VoldemortGin/claude-skills
```

Then install the skill collection:

```
/plugin install custom-skills@linhan-claude-skills
```

Or browse interactively:

1. Run `/plugin` in Claude Code
2. Select `Browse and install plugins`
3. Select `linhan-claude-skills`
4. Choose `custom-skills` to install

### Method 2: Manual Copy

Copy any skill folder into your local skills directory:

```bash
# Global (available in all projects)
cp -r skills/pyo3-best-practices ~/.claude/skills/pyo3-best-practices

# Project-only (commit to git for team sharing)
cp -r skills/pyo3-best-practices .claude/skills/pyo3-best-practices
```

| Location | Scope | Use Case |
|----------|-------|----------|
| `~/.claude/skills/` | All projects | Personal toolkit |
| `./.claude/skills/` | Current project only | Team workflows, project-specific |

### Method 3: Symlink (Development)

Symlink from a local clone for live editing:

```bash
ln -s /path/to/claude-skills/skills/pyo3-best-practices ~/.claude/skills/pyo3-best-practices
```

Changes to the source SKILL.md take effect immediately without re-copying.

## How Skills Work

Skills are **automatically triggered** by Claude Code based on the `description` field in each skill's `SKILL.md`. You don't need to manually invoke them.

Examples:
- Ask "help me set up a PyO3 project" → `pyo3-best-practices` activates automatically
- Ask "how to bind a C++ class with pybind11" → `pybind11-best-practices` activates automatically
- Ask "build a Flask API" → neither skill activates (not relevant)

The `description` contains keywords and context that Claude uses to decide when a skill is relevant. Only the matching skill's instructions are loaded into context.

### Verify Installation

```
/skill
```

This lists all installed skills and their descriptions.

## Skills

| Skill | Description |
|-------|-------------|
| `pybind11-best-practices` | Production-ready guide for pybind11 C++/Python binding projects |
| `pyo3-best-practices` | Production-ready guide for PyO3 Rust-Python binding projects |
| `example-skill` | A starter example demonstrating skill structure |

## Skill Structure

Each skill is a self-contained folder under `skills/`:

```
skills/
└── my-skill/
    ├── SKILL.md          # Required: YAML frontmatter + instructions
    ├── TRIGGERS.txt      # Optional: test prompts for activation testing
    ├── LICENSE.txt        # Optional: license
    ├── scripts/           # Optional: helper scripts
    ├── templates/         # Optional: templates and resources
    └── references/        # Optional: reference documentation
```

### SKILL.md Format

```markdown
---
name: my-skill-name
description: What the skill does and when Claude should use it
---

# Skill Title

Instructions that Claude follows when this skill is active.
```

The `description` field is critical — it determines when and how the skill gets triggered. Include both what the skill does and specific keywords/contexts for activation.

## Creating a New Skill

1. Copy `skills/_template/` to `skills/your-skill-name/`
2. Edit `SKILL.md`: set `name` (lowercase, hyphens only, max 64 chars) and `description` (max 1024 chars)
3. Write instructions in the markdown body (keep under 5,000 words)
4. Optionally add `TRIGGERS.txt` with test prompts (`+` lines should trigger, `-` lines should not)
5. Register the path in `.claude-plugin/marketplace.json`
6. Run `python tests/validate_skills.py` to verify

## Validation

Run the structure validator to check all skills:

```bash
python tests/validate_skills.py
```

This checks:
- SKILL.md exists with valid YAML frontmatter
- `name` and `description` meet length/format constraints
- Body content is not empty and under 5,000 words
- All skills are registered in `marketplace.json`
- All marketplace references point to valid paths

## License

MIT
