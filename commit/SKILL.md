---
name: commit
description: Smart Git Commit - Create well-formatted git commits with conventional commit messages. Use when user wants to commit changes or asks for help with git commits.
disable-model-invocation: true
allowed-tools: Bash, Read, Grep
---

# Smart Git Commit

Create a well-formatted git commit following conventional commit standards.

## Steps

1. **Check current changes**
   - Run `git status` to see modified files
   - Run `git diff --staged` for staged changes
   - Run `git diff` for unstaged changes

2. **Analyze changes**
   - Understand what was modified
   - Identify the type of change (feat, fix, refactor, etc.)
   - Determine the scope (backend, frontend, api, ui, etc.)

3. **Generate commit message**
   Follow conventional commits format:
   ```
   <type>(<scope>): <description>

   [optional body]

   [optional footer]
   ```

   Types:
   - `feat`: New feature
   - `fix`: Bug fix
   - `refactor`: Code refactoring
   - `docs`: Documentation changes
   - `style`: Code style changes (formatting, etc.)
   - `test`: Adding or updating tests
   - `chore`: Maintenance tasks

   Scopes for this project:
   - `backend`: Python/FastAPI changes
   - `frontend`: React/TypeScript changes
   - `api`: API endpoint changes
   - `ui`: UI component changes
   - `db`: Database model changes
   - `ai`: AI service/provider changes

4. **Execute commit**
   - Stage relevant files if needed
   - Create the commit with the generated message

## Example Output

```bash
git add backend/src/routes.py
git commit -m "feat(api): add pagination to manga list endpoint

- Add page and limit query parameters
- Return total count in response
- Update schema to include pagination metadata"
```

## Notes
- Keep the first line under 72 characters
- Use imperative mood ("add" not "added")
- Reference issue numbers if applicable
