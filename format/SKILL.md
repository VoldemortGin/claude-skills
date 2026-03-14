---
name: format
description: Auto Format Code - Format Python and TypeScript code according to project standards. Use when user asks to format code or fix code style issues.
disable-model-invocation: true
allowed-tools: Bash, Read, Edit
---

# Auto Format Code

Format code according to project standards.

## Python Formatting

### Tools to use (in order of preference):
1. **ruff** - Fast Python linter and formatter
   ```bash
   cd backend && ruff format .
   cd backend && ruff check --fix .
   ```

2. **black** - Code formatter (fallback)
   ```bash
   cd backend && black .
   ```

3. **isort** - Import sorting
   ```bash
   cd backend && isort .
   ```

### Import Order Standard
```python
# 1. Built-in modules
import os
import sys

# 2. Third-party libraries
from fastapi import FastAPI
from sqlalchemy import Column

# 3. Configuration/setup
import rootutils
ROOT_DIR = rootutils.setup_root(...)

# 4. Local imports
from src.models import Manga
from src.schemas import MangaCreate
```

## TypeScript/React Formatting

### Tools to use:
1. **prettier** - Code formatter
   ```bash
   cd frontend && npx prettier --write "src/**/*.{ts,tsx,js,jsx}"
   ```

2. **eslint** - Linter with auto-fix
   ```bash
   cd frontend && npx eslint --fix "src/**/*.{ts,tsx}"
   ```

## Steps

1. Check which formatters are available in the project
2. Run the appropriate formatter for the file type
3. Report any issues that couldn't be auto-fixed

## Notes
- Always run formatters from the appropriate directory (backend/ or frontend/)
- Check package.json and pyproject.toml for project-specific configurations
- Don't modify files that are in .gitignore
