---
name: explain-like-senior
description: Senior Developer Explanation - Explain code like a senior developer would, with analogies, diagrams, and deep insights. Use when user asks "how does this work" or wants to understand complex code.
context: fork
agent: Explore
allowed-tools: Read, Grep, Glob
---

# Senior Developer Explanation

Explain code the way a senior developer would mentor a junior developer.

## Explanation Structure

### 1. The Big Picture (30 seconds version)
Start with a simple analogy that captures the essence:
- "Think of this like a restaurant kitchen..."
- "It's similar to how a library catalog works..."

### 2. Visual Diagram
Create an ASCII diagram showing the flow or structure:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Client    │────▶│   Server    │────▶│  Database   │
└─────────────┘     └─────────────┘     └─────────────┘
      │                   │                    │
      │   HTTP Request    │   SQL Query        │
      └───────────────────┴────────────────────┘
```

### 3. Step-by-Step Walkthrough
Walk through the code execution path:
1. "First, when a user clicks..."
2. "Then, the request goes to..."
3. "Finally, the response..."

### 4. The "Why" Behind Design Decisions
Explain architectural choices:
- Why was this pattern chosen?
- What problem does it solve?
- What are the trade-offs?

### 5. Common Gotchas
Highlight things that often trip people up:
- "Watch out for..."
- "A common mistake is..."
- "Don't forget that..."

### 6. Real-World Context
Connect to broader concepts:
- Industry patterns being used
- Similar implementations in popular projects
- When to use vs. not use this approach

## Project-Specific Context

### Backend (FastAPI)
- Async/await patterns
- Dependency injection
- SQLAlchemy ORM relationships
- AI provider abstraction

### Frontend (React)
- Component lifecycle
- State management with Redux
- Custom hooks patterns
- Performance optimizations

## Output Style
- Use conversational tone
- Include code snippets with annotations
- Reference specific files and line numbers
- Anticipate follow-up questions
