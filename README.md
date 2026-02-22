# Claude Skills

A collection of custom Claude Code skills for daily development workflows.

## Usage

### Claude Code

Register this repository as a plugin marketplace:

```
/plugin marketplace add <your-github-username>/claude-skills
```

Then install skills:

```
/plugin install custom-skills@linhan-claude-skills
```

Or install directly from the marketplace browser:

1. `/plugin` → Browse and install plugins
2. Select `linhan-claude-skills`
3. Choose a skill set to install

### Manual Installation

Copy any skill folder into your local skills directory:

- **Personal**: `~/.claude/skills/<skill-name>/`
- **Project**: `./.claude/skills/<skill-name>/`

## Skill Structure

Each skill is a self-contained folder under `skills/`:

```
skills/
└── my-skill/
    ├── SKILL.md          # Required: YAML frontmatter + instructions
    ├── LICENSE.txt        # Optional: license for this skill
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

## Creating a New Skill

1. Copy `skills/_template/` to `skills/your-skill-name/`
2. Edit `SKILL.md` with your skill's metadata and instructions
3. Add any supporting files (scripts, templates, references)
4. Register it in `.claude-plugin/marketplace.json`

## Skills

| Skill | Description |
|-------|-------------|
| `pybind11-best-practices` | Production-ready guide for pybind11 C++/Python binding projects |
| `pyo3-best-practices` | Production-ready guide for PyO3 Rust-Python binding projects |
| `example-skill` | A starter example demonstrating skill structure |

## Validation

Run the structure validator to check all skills:

```bash
python tests/validate_skills.py
```

Each skill can also include a `TRIGGERS.txt` with test prompts (lines starting with `+` should trigger the skill, `-` should not). These are for manual testing with Claude Code.

## License

MIT
