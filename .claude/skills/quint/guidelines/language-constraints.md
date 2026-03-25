# Quint Language Constraints

**CRITICAL**: These are fundamental limitations of the Quint language. Violating them causes compilation errors that cannot be worked around.

## 1. No String Manipulation

Quint treats strings as **opaque values** for comparison only.

**NOT allowed:**
- String concatenation: `"hello" + "world"`
- String interpolation: `"value: ${x}"`
- String indexing: `str[0]`
- String methods: `.length()`, `.substring()`, `.toUpperCase()`
- Converting values to strings: `toString(42)`

**Allowed:**
- String literals: `"hello"`
- String comparison: `name == "Alice"`
- Strings as map keys or set elements

**Solution**: Use sum types or structured data instead of strings:
```quint
type Printed = PrintedInt(int) | PrintedBool(bool) | PrintedString(str)
```

## 2. No Nested Pattern Matching

Match one level at a time only.

```quint
// WRONG - nested match:
match msg
  | Request(Prepare(n, v)) => ...

// RIGHT - sequential match:
match msg
  | Request(inner) =>
      match inner
        | Prepare(r) => r.n
        | Promise(r) => r.round
  | Response(resp) =>
      val status = resp.status
      match status
        | Ok => ...
        | Error => ...
```

## 3. No Destructuring

Cannot destructure tuples or records in binding positions.

```quint
// WRONG:
val (x, y) = get_pair()
val { name, age } = person
def process_pair((a, b)) = a + b

// RIGHT:
val pair = get_pair()
val x = pair._1
val y = pair._2
val person_name = person.name
def process_pair(p) = p._1 + p._2
```

## 4. No Mutable Variables

- `val` bindings are immutable
- Use state variables with `'` suffix for mutable state across transitions
- Within a definition, you cannot reassign: `var x = 1; x = 2` is NOT valid

## 5. No Loops

Use functional alternatives:
- `S.map(x => x + 1)` instead of `for x in S`
- `S.filter(x => x > 0)` for filtering
- `S.fold(0, (acc, x) => acc + x)` for accumulation
- `S.forall(x => x > 0)` for universal checks
- `S.exists(x => x > 0)` for existential checks

## 6. No Early Returns

Functions must have a single expression as their body. Use `if-then-else` or `match`:

```quint
// WRONG (conceptually):
// if (bad) return error
// do_stuff()

// RIGHT:
if (bad) { errorResult } else { do_stuff() }
```

## 7. Type Inference Limitations

- Quint has good type inference, but sometimes needs explicit annotations
- Especially with polymorphic operators or empty collections
- `Set()` needs type context — prefer `Set(1, 2, 3)` or annotated binding
- Empty maps need explicit types

## Debugging Workflow

When you encounter a compilation error:
1. **Check these constraints first** — most errors stem from violating these rules
2. **Read the error message carefully** — Quint's type checker is precise
3. **Simplify the expression** — break complex expressions into smaller steps
4. **Use intermediate bindings** — `val temp = expr1` then use `temp` in `expr2`
5. **Match one level at a time** — never try to match nested patterns
