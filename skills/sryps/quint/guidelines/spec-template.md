# Standard Quint Spec Template

Use this template for: smart contracts, state machines, DeFi protocols, algorithms, games, general systems.

## Architecture: State Type + Pure Functions + Thin Actions

This is the mandatory pattern. All business logic goes in pure functions. Actions are thin wrappers.

## Template

```quint
// {Module Name}
// {Brief description}
module {ModuleName} {

  // ═══════════════════════════════════════════
  // 1. TYPES — Define your data structures
  // ═══════════════════════════════════════════
  type Address = str
  type Amount = int

  // Sum types for enums:
  type Phase = Propose | Vote | Decide

  // State type encapsulates ALL state
  type State = {
    field1: SomeType,
    field2: Address -> Amount,
    users: Set[Address]
  }

  // ═══════════════════════════════════════════
  // 2. CONSTANTS — Configuration values
  // ═══════════════════════════════════════════
  pure val INITIAL_BALANCE = 1000
  pure val INITIAL_USERS: Set[Address] = Set("alice", "bob", "charlie")

  // Use const for parameterized specs:
  // const N: int
  // const F: int

  // ═══════════════════════════════════════════
  // 3. PURE FUNCTIONS — ALL business logic here
  // ═══════════════════════════════════════════

  /// Core operation — pure function does ALL the work
  /// Returns {success, newState} so actions stay thin
  pure def calculateOperation(
    state: State,
    user: Address,
    amount: Amount
  ): { success: bool, newState: State } = {
    // Validation
    val canPerform = state.users.contains(user) and state.field2.get(user) >= amount

    if (canPerform) {
      val newField2 = state.field2.put(user, state.field2.get(user) - amount)
      {
        success: true,
        newState: { ...state, field2: newField2 }
      }
    } else {
      { success: false, newState: state }
    }
  }

  // ═══════════════════════════════════════════
  // 4. STATE VARIABLES — Match State type fields
  // ═══════════════════════════════════════════
  var field1: SomeType
  var field2: Address -> Amount
  var users: Set[Address]

  // Helper to get current state as State record
  val currentState: State = {
    field1: field1,
    field2: field2,
    users: users
  }

  // ═══════════════════════════════════════════
  // 5. INVARIANTS — Safety properties
  // ═══════════════════════════════════════════
  val noNegativeBalances: bool = users.forall(u => field2.get(u) >= 0)

  // ═══════════════════════════════════════════
  // 6. THIN ACTIONS — Call pure functions + update state
  // ═══════════════════════════════════════════

  /// No-op action for failed operations
  action unchanged_all = all {
    field1' = field1,
    field2' = field2,
    users' = users,
  }

  action performOperation(user: Address, amount: Amount): bool = {
    val result = calculateOperation(currentState, user, amount)
    if (result.success) {
      all {
        field1' = result.newState.field1,
        field2' = result.newState.field2,
        users' = result.newState.users,
      }
    } else {
      unchanged_all
    }
  }

  // ═══════════════════════════════════════════
  // 7. ACTION WITNESSES — Reachability checks
  // ═══════════════════════════════════════════
  // These go in a separate witness file, but can also be inline
  val canPerformSuccessfully: bool = not(field2.get("alice") < INITIAL_BALANCE)

  // ═══════════════════════════════════════════
  // 8. INITIALIZATION — Pre-populate ALL maps with mapBy
  // ═══════════════════════════════════════════
  action init = all {
    field1' = initialValue,
    field2' = INITIAL_USERS.mapBy(user => INITIAL_BALANCE),
    users' = INITIAL_USERS,
  }

  // ═══════════════════════════════════════════
  // 9. STEP ACTION — Nondeterministic exploration
  // ═══════════════════════════════════════════
  action step = {
    nondet user = INITIAL_USERS.oneOf()
    nondet amount = 1.to(100).oneOf()
    any {
      performOperation(user, amount),
    }
  }
}
```

## Key Principles

1. **State type encapsulates ALL state variables** — mirror fields exactly
2. **Pure functions contain ALL business logic** — validation, computation, state changes
3. **Pure functions return `{success: bool, newState: State}`** — enables thin actions
4. **Actions are thin wrappers** — call pure function, check success, update vars
5. **Use `{...state, field: newValue}` spread syntax** for state updates
6. **Pre-populate ALL maps with `mapBy`** — prevents undefined key access
7. **`unchanged_all` action** — reusable no-op for failed operations
8. **`currentState` val binding** — bridges state vars to State record for pure functions
9. **Every action assigns ALL state variables** — use `unchanged_all` or explicit `var' = var`

## Test File Template

Create a separate test file that imports the spec:

```quint
module {moduleName}Test {
  import {ModuleName}.* from "./{moduleName}"

  run basicOperationTest = {
    init
      .expect(
        and {
          field1 == initialValue,
          users.size() == 3,
          field2.get("alice") == INITIAL_BALANCE,
        }
      )
      .then(performOperation("alice", 42))
      .expect(
        and {
          field2.get("alice") == INITIAL_BALANCE - 42,
        }
      )
  }

  run failedOperationTest = {
    init
      .then(performOperation("alice", INITIAL_BALANCE + 1))
      .expect(field2.get("alice") == INITIAL_BALANCE)
  }
}
```

Run tests with:
```bash
quint test {test_file} --main={testModule} --match=".*"
```
