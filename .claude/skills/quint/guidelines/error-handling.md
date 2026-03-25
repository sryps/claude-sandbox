# Error Handling Guide

## Typecheck Error Decision Tree

```
If parse fails:
  → Parse Error Protocol
If typecheck fails:
  Read error message
  If "not in scope" → Scope Error Protocol
  If "type mismatch" → Type Mismatch Protocol
  If "missing type annotation" → Annotation Protocol
  Else → General Error Protocol
```

## Parse Error Protocol

### Common Parse Errors

| Error Message | Cause | Fix |
|---------------|-------|-----|
| "missing closing brace" | Unbalanced `{}` | Count braces, add missing `}` |
| "missing comma" | Missing separator in `all{}` or `any{}` | Add comma after last item |
| "unexpected token '}'" | Extra closing brace or missing opening | Check brace pairing |
| "unexpected token in module" | Code outside module or wrong insertion | Check placement |

### Fix Attempts

**Attempt 1 — Simple syntax correction:**
- Missing brace: count `{` vs `}`, add missing one
- Missing comma: add after last item in list
- Unexpected token: compare against syntax reference

**Attempt 2 — Structure review:**
- Read surrounding 10 lines for context
- Check indentation and nesting
- Verify definition is inside module braces

**Attempt 3 — Rewrite the construct:**
- Delete the problematic section
- Rewrite from scratch using syntax reference
- Re-run parse

After 3 failed attempts: escalate to user.

## Type Error Protocol

### Scope Errors ("not in scope")

**Fix Attempt 1 — Check definition exists:**
```bash
grep "element_name" spec_file
```
If not found: add the missing definition before first usage.

**Fix Attempt 2 — Check imports:**
- Is the element in a different module?
- Add `import Module.* from "./file"` if needed

**Fix Attempt 3 — Check definition order:**
- Is it used before it's defined?
- Move definition earlier in the file

### Type Mismatch Errors

1. Read error: "expected X, got Y"
2. Find the expression at the error location
3. Common fixes:
   - Wrong type in record field → fix the value
   - Set vs element confusion → wrap in `Set()` or unwrap
   - Map type wrong → check `Key -> Value` syntax
   - Missing `.get()` on map → add `.get(key)`

### Missing Annotation Errors

- Add explicit type annotation to the definition
- Common spots: empty collections, polymorphic operations
- Example: `val x: Set[int] = Set()` instead of `val x = Set()`

## Common LLM Mistakes

These are the errors most frequently made when generating Quint code:

### 1. String manipulation
**Error**: Trying to concatenate or format strings
**Fix**: Use sum types, records, or structured data instead

### 2. Nested pattern matching
**Error**: `match x | Foo(Bar(y)) => ...`
**Fix**: Sequential matches — `match x | Foo(inner) => match inner | Bar(y) => ...`

### 3. Destructuring
**Error**: `val (x, y) = pair` or `val {a, b} = record`
**Fix**: `val x = pair._1; val y = pair._2` or `val a = record.a`

### 4. Wrong oneOf syntax
**Error**: `oneOf(S)` or `nondet x = oneOf(set)`
**Fix**: `nondet x = S.oneOf()`

### 5. Map type syntax
**Error**: `Map[str, int]` or `Map<str, int>`
**Fix**: `str -> int`

### 6. Missing state variable assignments
**Error**: Action only assigns some state variables
**Fix**: Add `var' = var` for all unchanged variables, or use `unchanged_all`

### 7. Using loops
**Error**: `for`, `while`, `loop`
**Fix**: Use `.map()`, `.filter()`, `.fold()`, `.forall()`, `.exists()`

### 8. Mutable variables
**Error**: `var x = 1; x = x + 1` inside a definition
**Fix**: Use `val` bindings: `val x = 1; val y = x + 1`

### 9. Not pre-populating maps
**Error**: Creating empty maps then accessing keys
**Fix**: `KEYS.mapBy(k => defaultValue)` in init

### 10. Pure def with parentheses when no params
**Error**: `pure def myVal() = ...`
**Fix**: `pure def myVal = ...`

## Iteration Protocol

```
max_iterations = 5

For each iteration:
  1. Run: quint typecheck {file}
  2. If passes: done
  3. If fails:
     a. Read error message
     b. Identify error type from table above
     c. Apply appropriate fix
     d. Continue to next iteration

If iteration >= 5 and still failing:
  Show error to user
  Ask for guidance
```

## Collateral Damage

If your fix breaks something else:
1. Check if your change affected brace nesting (most common)
2. Check for name conflicts with existing definitions
3. Check that imports still resolve
4. If unclear, revert the change and try a different approach
