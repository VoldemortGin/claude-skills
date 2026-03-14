---
name: implement
description: Smart Implementation Engine - Implement features following project patterns and best practices. Use when user asks to add a new feature, endpoint, or component.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# Smart Implementation Engine

Implement new features following existing project patterns.

## Pre-Implementation Checklist

1. **Understand the requirement**
   - What exactly needs to be built?
   - What are the inputs and outputs?
   - Are there edge cases to handle?

2. **Find existing patterns**
   - Look for similar implementations in the codebase
   - Identify the conventions being used
   - Note any project-specific utilities

3. **Plan the implementation**
   - List files that need to be created/modified
   - Identify dependencies
   - Consider testing strategy

## Backend Implementation (FastAPI)

### New API Endpoint
1. Add route in `backend/src/routes.py`
2. Add schema in `backend/src/schemas.py`
3. Add model if needed in `backend/src/models.py`
4. Update service layer if complex logic

### Pattern to follow:
```python
@router.post("/resource", response_model=ResourceResponse)
async def create_resource(
    data: ResourceCreate,
    db: Session = Depends(get_db)
) -> ResourceResponse:
    """Create a new resource."""
    # Implementation
    pass
```

## Frontend Implementation (React)

### New Component
1. Create component in `frontend/src/components/`
2. Add types in component file or separate types file
3. Connect to Redux store if needed
4. Add to page or parent component

### Pattern to follow:
```typescript
interface Props {
  // Props definition
}

export const ComponentName: React.FC<Props> = ({ prop1, prop2 }) => {
  // Hooks
  const [state, setState] = useState<Type>(initial);

  // Effects
  useEffect(() => {
    // Side effects
  }, [dependencies]);

  // Handlers
  const handleAction = () => {
    // Handler logic
  };

  return (
    <div>
      {/* JSX */}
    </div>
  );
};
```

### New Page
1. Create page in `frontend/src/pages/`
2. Add route in router configuration
3. Connect to Redux store
4. Add navigation link if needed

## Implementation Standards

- Follow existing code style
- Add proper type hints (Python) / types (TypeScript)
- Handle errors appropriately
- Keep functions focused and small
- Don't over-engineer - implement what's needed

## Output Format

```
## Implementation Plan
[List of changes to make]

## Files Modified
- file1.py: [what changed]
- file2.tsx: [what changed]

## Testing Notes
[How to test the implementation]
```
