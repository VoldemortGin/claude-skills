---
name: fix-imports
description: Fix Broken Imports - Diagnose and fix import errors in Python and TypeScript files. Use when user encounters import errors or module not found issues.
allowed-tools: Read, Edit, Grep, Glob, Bash
---

# Fix Broken Imports

Diagnose and fix import errors in the codebase.

## Python Import Issues

### Common Problems & Solutions

1. **Module not found**
   - Check if the module is installed: `pip list | grep <module>`
   - Check if it's in requirements.txt
   - Verify PYTHONPATH includes the project root

2. **Relative import errors**
   - Ensure `__init__.py` exists in package directories
   - Use absolute imports from project root
   - Check rootutils setup is correct

3. **Circular imports**
   - Move shared types to a separate module
   - Use TYPE_CHECKING for type-only imports
   - Restructure dependencies

### Project Import Pattern
```python
import os

from dotenv import load_dotenv
import rootutils

ROOT_DIR = rootutils.setup_root(os.getcwd(), indicator='.project-root', pythonpath=True)
load_dotenv(ROOT_DIR / '.env')

from src.xxx import yyy
```

## TypeScript Import Issues

### Common Problems & Solutions

1. **Module not found**
   - Check if package is in package.json
   - Run `npm install` or `yarn`
   - Check tsconfig.json paths configuration

2. **Path alias issues**
   - Verify `@/` alias in tsconfig.json
   - Check vite.config.ts resolve.alias

3. **Type declaration missing**
   - Install @types/<package> for type definitions
   - Create custom .d.ts file if needed

## Diagnostic Steps

1. Read the error message carefully
2. Locate the file with the import error
3. Check if the imported module/file exists
4. Verify the import path is correct
5. Check for typos in module names
6. Ensure dependencies are installed

## Output Format

```
## Issue Found
[Description of the import problem]

## Root Cause
[Why this error is occurring]

## Fix Applied
[What was changed to fix it]

## Prevention
[How to avoid this in the future]
```
