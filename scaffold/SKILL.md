---
name: scaffold
description: Intelligent Scaffolding - Generate boilerplate code for new components, pages, or modules. Use when user wants to create new files with standard structure.
disable-model-invocation: true
argument-hint: "[type] [name]"
allowed-tools: Write, Read, Glob
---

# Intelligent Scaffolding

Generate boilerplate code following project conventions.

## Usage
`/scaffold [type] [name]`

Examples:
- `/scaffold component UserCard`
- `/scaffold page Settings`
- `/scaffold endpoint users`
- `/scaffold hook useAuth`

## Scaffold Types

### React Component (`component`)
Creates: `src/components/{Name}.tsx` or `src/components/{Name}/{Name}.tsx`

```typescript
import React from 'react';

interface {Name}Props {
  // Define props here
}

export const {Name}: React.FC<{Name}Props> = (props) => {
  return (
    <div className="">
      {/* Component content */}
    </div>
  );
};

export default {Name};
```

### React Page (`page`)
Creates: `src/pages/{Name}Page.tsx`

```typescript
import React, { useEffect, useState } from 'react';

const {Name}Page: React.FC = () => {
  useEffect(() => {
    // Load data on mount
  }, []);

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-6">{Name}</h1>
      {/* Page content */}
    </div>
  );
};

export default {Name}Page;
```

### React Hook (`hook`)
Creates: `src/hooks/{name}.ts`

```typescript
import { useState, useEffect, useCallback } from 'react';

export function {name}() {
  const [state, setState] = useState<any>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  // Hook logic here

  return { state, loading, error };
}
```

### FastAPI Endpoint (`endpoint`)
Adds to: `routes.py` and `schemas.py`

```python
# In schemas.py
class {Name}Create(BaseModel):
    pass

class {Name}Response(BaseModel):
    id: int

    class Config:
        from_attributes = True

# In routes.py
@router.post("/{name}", response_model={Name}Response)
async def create_{name}(
    data: {Name}Create,
    db: Session = Depends(get_db)
) -> {Name}Response:
    """Create a new {name}."""
    pass
```

### Python Service (`service`)
Creates: `src/services/{name}_service.py`

```python
from typing import Optional

class {Name}Service:
    """Service for {name} operations."""

    def __init__(self):
        pass

    async def create(self, data: dict) -> dict:
        """Create a new {name}."""
        pass

    async def get(self, id: int) -> Optional[dict]:
        """Get {name} by ID."""
        pass

    async def list(self, limit: int = 10, offset: int = 0) -> list:
        """List all {name}s."""
        pass
```

## Notes
- Replace `{Name}` with PascalCase name
- Replace `{name}` with camelCase/snake_case name
- Replace `{NAME}` with UPPER_SNAKE_CASE name
- Adjust imports based on actual project structure
- First check existing patterns in the project before scaffolding
