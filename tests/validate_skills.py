"""
Skill structure and content validator.

Validates that all skills in the repository follow the correct format
and best practices. Run from the project root:

    python tests/validate_skills.py
"""
import os
import re
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).parent.parent
SKILLS_DIR = ROOT_DIR / "skills"
MARKETPLACE_FILE = ROOT_DIR / ".claude-plugin" / "marketplace.json"

# Constraints from the spec
MAX_NAME_LENGTH = 64
MAX_DESCRIPTION_LENGTH = 1024
MAX_CONTENT_WORDS = 5000
NAME_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]*$")


class ValidationError:
    def __init__(self, skill: str, message: str):
        self.skill = skill
        self.message = message

    def __str__(self):
        return f"  [{self.skill}] {self.message}"


def parse_frontmatter(content: str) -> tuple[dict[str, str], str]:
    """Parse YAML frontmatter from SKILL.md content."""
    if not content.startswith("---"):
        return {}, content

    parts = content.split("---", 2)
    if len(parts) < 3:
        return {}, content

    frontmatter = {}
    for line in parts[1].strip().splitlines():
        if ":" in line:
            key, _, value = line.partition(":")
            frontmatter[key.strip()] = value.strip()

    body = parts[2].strip()
    return frontmatter, body


def validate_skill(skill_dir: Path) -> list[ValidationError]:
    """Validate a single skill directory."""
    errors: list[ValidationError] = []
    skill_name = skill_dir.name

    # Skip template
    if skill_name.startswith("_"):
        return errors

    skill_md = skill_dir / "SKILL.md"

    # 1. SKILL.md must exist
    if not skill_md.exists():
        errors.append(ValidationError(skill_name, "Missing SKILL.md"))
        return errors

    content = skill_md.read_text(encoding="utf-8")

    # 2. Must have YAML frontmatter
    if not content.startswith("---"):
        errors.append(ValidationError(skill_name, "Missing YAML frontmatter (must start with ---)"))
        return errors

    frontmatter, body = parse_frontmatter(content)

    # 3. Must have 'name' field
    if "name" not in frontmatter:
        errors.append(ValidationError(skill_name, "Missing 'name' in frontmatter"))
    else:
        name = frontmatter["name"]
        if len(name) > MAX_NAME_LENGTH:
            errors.append(ValidationError(skill_name, f"Name too long: {len(name)} > {MAX_NAME_LENGTH} chars"))
        if not NAME_PATTERN.match(name):
            errors.append(ValidationError(skill_name, f"Name '{name}' must be lowercase, numbers, hyphens only"))
        if name != skill_name:
            errors.append(ValidationError(skill_name, f"Name '{name}' doesn't match directory name '{skill_name}'"))

    # 4. Must have 'description' field
    if "description" not in frontmatter:
        errors.append(ValidationError(skill_name, "Missing 'description' in frontmatter"))
    else:
        desc = frontmatter["description"]
        if len(desc) > MAX_DESCRIPTION_LENGTH:
            errors.append(ValidationError(skill_name, f"Description too long: {len(desc)} > {MAX_DESCRIPTION_LENGTH} chars"))
        if len(desc) < 20:
            errors.append(ValidationError(skill_name, "Description too short (< 20 chars). Include what and when."))

    # 5. Body should not be empty
    if not body.strip():
        errors.append(ValidationError(skill_name, "SKILL.md body is empty (no instructions)"))

    # 6. Word count check
    word_count = len(body.split())
    if word_count > MAX_CONTENT_WORDS:
        errors.append(ValidationError(skill_name, f"Body too long: {word_count} > {MAX_CONTENT_WORDS} words"))

    # 7. Body should have at least one heading
    if not re.search(r"^#+ ", body, re.MULTILINE):
        errors.append(ValidationError(skill_name, "Body has no markdown headings"))

    return errors


def validate_marketplace() -> list[ValidationError]:
    """Validate marketplace.json references."""
    import json

    errors: list[ValidationError] = []

    if not MARKETPLACE_FILE.exists():
        errors.append(ValidationError("marketplace", "Missing .claude-plugin/marketplace.json"))
        return errors

    try:
        data = json.loads(MARKETPLACE_FILE.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        errors.append(ValidationError("marketplace", f"Invalid JSON: {e}"))
        return errors

    # Check required top-level fields
    for field in ["name", "owner", "metadata", "plugins"]:
        if field not in data:
            errors.append(ValidationError("marketplace", f"Missing required field: '{field}'"))

    # Check each plugin's skill paths exist
    for plugin in data.get("plugins", []):
        for skill_path in plugin.get("skills", []):
            resolved = ROOT_DIR / skill_path
            if not resolved.exists():
                errors.append(ValidationError("marketplace", f"Skill path not found: {skill_path}"))
            elif not (resolved / "SKILL.md").exists():
                errors.append(ValidationError("marketplace", f"No SKILL.md in referenced path: {skill_path}"))

    # Check all non-template skills are registered
    registered_paths = set()
    for plugin in data.get("plugins", []):
        for skill_path in plugin.get("skills", []):
            registered_paths.add(Path(skill_path).name)

    for skill_dir in SKILLS_DIR.iterdir():
        if skill_dir.is_dir() and not skill_dir.name.startswith("_"):
            if skill_dir.name not in registered_paths:
                errors.append(ValidationError("marketplace", f"Skill '{skill_dir.name}' not registered in marketplace.json"))

    return errors


def validate_trigger_prompts(skill_dir: Path) -> list[ValidationError]:
    """Validate trigger test prompts if they exist."""
    errors: list[ValidationError] = []
    skill_name = skill_dir.name
    triggers_file = skill_dir / "TRIGGERS.txt"

    if not triggers_file.exists():
        return errors

    lines = triggers_file.read_text(encoding="utf-8").strip().splitlines()
    positive = [l for l in lines if l.startswith("+")]
    negative = [l for l in lines if l.startswith("-")]

    if len(positive) < 3:
        errors.append(ValidationError(skill_name, f"TRIGGERS.txt: need at least 3 positive triggers, got {len(positive)}"))
    if len(negative) < 2:
        errors.append(ValidationError(skill_name, f"TRIGGERS.txt: need at least 2 negative triggers, got {len(negative)}"))

    return errors


def main():
    all_errors: list[ValidationError] = []

    # Validate marketplace
    all_errors.extend(validate_marketplace())

    # Validate each skill
    if SKILLS_DIR.exists():
        for skill_dir in sorted(SKILLS_DIR.iterdir()):
            if skill_dir.is_dir():
                all_errors.extend(validate_skill(skill_dir))
                all_errors.extend(validate_trigger_prompts(skill_dir))

    # Report
    if all_errors:
        print(f"FAILED: {len(all_errors)} validation error(s)\n")
        for err in all_errors:
            print(err)
        sys.exit(1)
    else:
        skill_count = sum(1 for d in SKILLS_DIR.iterdir() if d.is_dir() and not d.name.startswith("_"))
        print(f"PASSED: All {skill_count} skill(s) validated successfully")
        sys.exit(0)


if __name__ == "__main__":
    main()
