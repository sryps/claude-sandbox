# Quint Syntax Reference

Quick reference for correct Quint syntax. Consult this before generating code.

## Core Syntax Rules

### Pure Definitions

```quint
// No params — NO parentheses:
pure def name = expression

// With params:
pure def name(param: Type): ReturnType = expression

// Pure val (constant):
pure val CONSTANT = value
```

### oneOf Syntax

```quint
// CORRECT — method call on collection:
nondet node = NODES.oneOf()
nondet amount = 1.to(100).oneOf()

// WRONG:
nondet node = oneOf(NODES)
```

### Map Operations

```quint
// Type syntax (NOT Map[K, V]):
KeyType -> ValueType

// Create:
Map(("alice", 100), ("bob", 200))

// Pre-populate ALL keys (CRITICAL — prevents undefined behavior):
USERS.mapBy(u => 0)

// Get:
m.get(key)

// Put (returns new map):
m.put(key, value)

// Keys/values:
m.keys()
```

### Set Operations

```quint
// Create:
Set(1, 2, 3)

// Operations:
s.union(other)
s.intersect(other)
s.exclude(other)
s.contains(elem)
s.subseteq(other)
s.size()
s.map(f)
s.filter(f)
s.fold(init, f)
s.forall(f)
s.exists(f)
s.flatten()
s.powerset()

// Add element:
s.union(Set(elem))
```

### Sum Types (Unions)

```quint
// Definition:
type Message =
  | Propose({ sender: Node, value: Value })
  | Vote({ sender: Node, value: Value })
  | Decide({ sender: Node, value: Value })
  | Timeout  // variant with no data

// Construction — variant constructors take a SINGLE argument:
Propose({ sender: "alice", value: 42 })
Timeout  // no argument for unit variant

// For tuples as data:
Timeout((height, round))  // tuple as single arg
// Access with ._1, ._2 after binding

// Pattern matching:
match msg
  | Propose(p) => p.sender
  | Vote(v) => v.value
  | Decide(d) => d.value
  | Timeout => "timeout"
```

### Record Operations

```quint
// Create:
{ field1: value1, field2: value2 }

// Access:
record.field

// Update (spread syntax — returns new record):
{ ...record, field: newValue }

// Multiple updates:
{ ...record, field1: newValue1, field2: newValue2 }
```

### Tuple Operations

```quint
// Create:
(value1, value2)

// Access (1-indexed):
tuple._1
tuple._2
```

### Actions

```quint
// Action definition:
action myAction(param: Type): bool = all {
  // precondition
  someCondition,
  // state updates (ALL vars must be assigned)
  var1' = newValue,
  var2' = var2,  // unchanged
}

// Conjunctive (all updates together):
all { update1, update2, update3 }

// Disjunctive (choice):
any { action1, action2, action3 }

// Nondeterministic step:
action step = {
  nondet node = NODES.oneOf()
  nondet value = VALUES.oneOf()
  any {
    action1(node, value),
    action2(node),
  }
}
```

### State Variables

```quint
// Declaration:
var myVar: Type

// Update (in actions, using prime):
myVar' = newValue

// CRITICAL: Every action must assign ALL state variables
// Use unchanged pattern for vars that don't change:
myVar' = myVar
```

### Invariants and Witnesses

```quint
// Invariant (safety — should always hold):
val noNegativeBalances: bool = USERS.forall(u => balances.get(u) >= 0)

// Witness (negated reachability goal — should be VIOLATED):
val canReachDecision: bool = not(NODES.exists(n => decided.get(n) != None))
```

### Tests (run definitions)

```quint
run basicTest = {
  init
    .then(action1(param))
    .expect(condition1)
    .then(action2(param))
    .expect(condition2)
}

// Nondeterministic test:
run randomTest = {
  nondet user = USERS.oneOf()
  init
    .then(action(user))
    .expect(safetyCondition)
}
```

### filterMap

```quint
// Filter + transform in one pass:
msgs.filterMap(m => match m {
  | Propose(p) => Some(p.sender)
  | _ => None
})
```

### Module System

```quint
// Import all:
import ModuleName.* from "./filename"

// Import with parameters:
import ModuleName(PARAM1 = value1, PARAM2 = value2).* from "./filename"

// Qualified import:
import ModuleName from "./filename"
// Use as: ModuleName::something
```

## Common Gotchas

1. **`oneOf()` is a method**, not a function: `S.oneOf()` not `oneOf(S)`
2. **Maps use `->` type syntax**: `str -> int` not `Map[str, int]`
3. **Always pre-populate maps** with `mapBy` to prevent undefined key access
4. **Variant constructors take one argument**: wrap multiple values in a record or tuple
5. **`pure def` with no params has no parens**: `pure def x = 5` not `pure def x() = 5`
6. **All state vars must be assigned in every action** — even unchanged ones
7. **`not()` is a function**: `not(condition)` not `!condition`
8. **Range**: `1.to(10)` creates `Set[int]` from 1 to 10 inclusive
