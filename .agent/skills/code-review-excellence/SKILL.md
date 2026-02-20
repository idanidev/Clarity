---
name: code-review-excellence
description: Transform code reviews from gatekeeping to knowledge sharing through constructive feedback, systematic analysis, and collaborative improvement.
---

# Code Review Excellence

Transform code reviews from gatekeeping to knowledge sharing through constructive feedback, systematic analysis, and collaborative improvement.

## Core Principles

### 1. The Review Mindset

Goals of Code Review:

- Catch bugs and edge cases
- Ensure code maintainability
- Share knowledge across team
- Enforce coding standards
- Improve design and architecture
- Build team culture

Not the Goals:

- Show off knowledge
- Nitpick formatting (use linters)
- Block progress unnecessarily
- Rewrite to your preference

### 2. Effective Feedback

Good Feedback is:

- Specific and actionable
- Educational, not judgmental
- Focused on the code, not the person
- Balanced (praise good work too)
- Prioritized (critical vs nice-to-have)

```
❌ Bad: "This is wrong."
✅ Good: "This could cause a race condition when multiple users access simultaneously. Consider using a mutex here."

❌ Bad: "Why didn't you use X pattern?
✅ Good: "Have you considered the Repository pattern? It would make this easier to test. Here's an example: [link]"

❌ Bad: "Rename this variable."
✅ Good: "[nit] Consider `userCount` instead of `uc` for clarity. Not blocking if you prefer to keep it."
```

### 3. Review Scope

What to Review:

- Logic correctness and edge cases
- Security vulnerabilities
- Performance implications
- Test coverage and quality
- Error handling
- Documentation and comments
- API design and naming
- Architectural fit

What Not to Review Manually:

- Code formatting (use Prettier, Black, etc.)
- Import organization
- Linting violations
- Simple typos

## Review Process

### Phase 1: Context Gathering (2-3 minutes)

1. Read PR description and linked issue
2. Check PR size (>400 lines? Ask to split)
3. Review CI/CD status (tests passing?)
4. Understand the business requirement
5. Note any relevant architectural decisions

### Phase 2: High-Level Review (5-10 minutes)

1. **Architecture & Design**
   - Does the solution fit the problem?
   - Are there simpler approaches?
   - Is it consistent with existing patterns?
   - Will it scale?
2. **File Organization**
   - Are new files in the right places?
   - Is code grouped logically?
   - Are there duplicate files?
3. **Testing Strategy**
   - Are there tests?
   - Do tests cover edge cases?
   - Are tests readable?

### Phase 3: Line-by-Line Review (10-20 minutes)

For each file:

1. **Logic & Correctness**
   - Edge cases handled?
   - Off-by-one errors?
   - Null/undefined checks?
   - Race conditions?
2. **Security**
   - Input validation?
   - SQL injection risks?
   - XSS vulnerabilities?
   - Sensitive data exposure?
3. **Performance**
   - N+1 queries?
   - Unnecessary loops?
   - Memory leaks?
   - Blocking operations?
4. **Maintainability**
   - Clear variable names?
   - Functions doing one thing?
   - Complex code commented?
   - Magic numbers extracted?

### Phase 4: Summary & Decision (2-3 minutes)

1. Summarize key concerns
2. Highlight what you liked
3. Make clear decision:
   - ✅ Approve
   - 💬 Comment (minor suggestions)
   - 🔄 Request Changes (must address)
4. Offer to pair if complex

## Language-Specific Patterns

### Python Code Review

```python
# Check for Python-specific issues
# ❌ Mutable default arguments
def add_item(item, items=[]): # Bug! Shared across calls
    items.append(item)
    return items

# ✅ Use None as default
def add_item(item, items=None):
    if items is None:
        items = []
    items.append(item)
    return items

# ❌ Catching too broad
try:
    result = risky_operation()
except: # Catches everything, even KeyboardInterrupt!
    pass

# ✅ Catch specific exceptions
try:
    result = risky_operation()
except ValueError as e:
    logger.error(f"Invalid value: {e}")
    raise
```

### TypeScript/JavaScript Code Review

```typescript
// Check for TypeScript-specific issues
// ❌ Using any defeats type safety
function processData(data: any) {
  // Avoid any
  return data.value;
}

// ✅ Use proper types
interface DataPayload {
  value: string;
}
function processData(data: DataPayload) {
  return data.value;
}

// ❌ Not handling async errors
async function fetchUser(id: string) {
  const response = await fetch(`/api/users/${id}`);
  return response.json(); // What if network fails?
}

// ✅ Handle errors properly
async function fetchUser(id: string): Promise<User> {
  try {
    const response = await fetch(`/api/users/${id}`);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    return await response.json();
  } catch (error) {
    console.error("Failed to fetch user:", error);
    throw error;
  }
}
```
