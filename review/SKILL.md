---
name: review
description: Code Review - Perform thorough code review with security, performance, and best practices checks. Use when reviewing PRs, checking code quality, or when user asks to review code.
context: fork
agent: Explore
allowed-tools: Read, Grep, Glob
---

# Code Review

Perform a comprehensive code review of the specified code or changes.

## Review Checklist

### 1. Security (Critical)
- SQL injection risks (check SQLAlchemy queries)
- XSS vulnerabilities (check React components)
- Authentication/authorization issues
- Sensitive data exposure (API keys, passwords)
- CORS configuration issues

### 2. Performance
- N+1 database queries
- Inefficient algorithms or loops
- Memory leaks (especially in React useEffect)
- Unnecessary re-renders in React components
- Large bundle sizes or missing lazy loading

### 3. Code Quality
- Type safety (TypeScript strict mode, Python type hints)
- Error handling completeness
- Code duplication
- Function/component complexity
- Naming conventions

### 4. Project-Specific Standards
- Python imports follow: built-in > 3rd party > config > local
- React components use proper hooks patterns
- API endpoints follow RESTful conventions
- Database models have proper relationships

## Output Format

Provide feedback in this structure:

```
## Summary
[Brief overview of the review]

## Critical Issues 🔴
[Security vulnerabilities, bugs that will cause failures]

## Warnings ⚠️
[Performance issues, potential bugs, code smells]

## Suggestions 💡
[Improvements, best practices, refactoring ideas]

## Positive Notes ✅
[Well-written code, good patterns observed]
```

Include specific file:line references for each issue.
