# Verification Guide

## Core Concepts

### Witnesses vs Invariants

| Aspect | Witnesses | Invariants |
|--------|-----------|------------|
| Purpose | Reachability / liveness | Safety |
| Formulation | Negated goals: `not(reached_state)` | Properties: `always_holds` |
| Expected result | **VIOLATED** = GOOD | **SATISFIED** = GOOD |
| Bad result | SATISFIED = concern | VIOLATED = BUG |

### Commands

```bash
# Witness check (expect VIOLATION):
quint run spec.qnt --main=Module --invariant=witnessName --max-steps=100 --max-samples=100 --backend=rust

# Invariant check (expect NO violation):
quint run spec.qnt --main=Module --invariant=invariantName --max-steps=200 --max-samples=500 --backend=rust

# Reproduce a violation with seed:
quint run spec.qnt --main=Module --invariant=name --seed=0x1234 --verbosity=3 --backend=rust

# Run deterministic tests:
quint test spec_test.qnt --main=TestModule --match="testName"
```

## Witness Generation

### What to Witness

Analyze the spec for these categories:

**Phase/Stage Progression:**
- If spec has `type Phase = A | B | C`, witness each phase: `not(phase == B)`, `not(phase == C)`
- If spec has `round: int`, witness progress: `not(round > 0)`, `not(round > 1)`

**Message Type Appearance:**
- For each variant in a `Message` sum type, witness its appearance:
  ```quint
  val canSeePropose = not(messages.exists(m => match m { | Propose(_) => true | _ => false }))
  ```

**Quorum/Majority Formation:**
- If quorum logic exists: `not(votes.size() >= quorumSize)`

**Timeout Triggers:**
- If timeouts exist: `not(timedOut == true)`

**Terminal States:**
- Decisions/commitments: `not(NODES.exists(n => decided.get(n) != None))`

**State Variable Changes:**
- Booleans: witness both values
- Sets: witness non-empty: `not(mySet.size() > 0)`
- Counters: witness non-zero: `not(counter > 0)`
- Maps: witness value changes from initial

**Multiple Actors:**
- Witness that more than one actor acts: `not(actorCount > 1)`

### Witness File Structure

```quint
// Witnesses for {ModuleName}
// VIOLATED = GOOD (scenario reachable) | SATISFIED = CONCERN (may be unreachable)
module {spec_name}_witnesses {
  // For parameterized specs, instantiate with concrete values:
  import {ModuleName}(N = 4, F = 1).* from "./{spec_name}"
  // For non-parameterized:
  // import {ModuleName}.* from "./{spec_name}"

  // --- Helper predicates for complex conditions ---
  def hasDecided = NODES.exists(n => decided.get(n) != None)
  def hasQuorum = votes.size() >= QUORUM_SIZE

  // --- Witnesses ---
  // Witness: Can reach decision
  val canReachDecision: bool = not(hasDecided)

  // Witness: Can form quorum
  val canFormQuorum: bool = not(hasQuorum)

  // Witness: Can progress rounds
  val canProgressRounds: bool = not(round > 0)
}
```

## Running Witnesses

### Basic Run

```bash
quint run {witness_file} --main={module} --invariant={name} --max-steps=100 --max-samples=100 --backend=rust
```

### Interpreting Results

| Output | Result | Meaning | Action |
|--------|--------|---------|--------|
| "An example execution" | VIOLATED | Scenario reachable | Record success |
| "No trace found" / "No violation found" | SATISFIED | Scenario NOT reached | Progressive increase |

### Progressive Increase Protocol

When a witness is not violated:

```
Attempt 1: --max-steps=100 --max-samples=100
Attempt 2: --max-steps=200 --max-samples=200
Attempt 3: --max-steps=500 --max-samples=500
```

If still satisfied after 3 attempts, diagnose:

1. Run with `--verbosity=3` to see what actions execute
2. Check: Are key actions reachable?
3. Check: Is the protocol stuck in a specific state?
4. Check: Is the witness condition too strong?

Root causes:
- `protocol_stuck_at_init` — init conditions prevent progress
- `liveness_bug_infinite_loop` — same action loops without progress
- `witness_too_strong` — weaken the witness definition
- `need_more_steps` — genuinely needs longer traces

## Running Invariants

### Basic Run

```bash
quint run {file} --main={module} --invariant={name} --max-steps=200 --max-samples=500 --backend=rust
```

### When Invariant is Violated (BUG)

1. **Capture seed** from output
2. **Get detailed trace:**
   ```bash
   quint run {file} --main={module} --invariant={name} --seed={seed} --verbosity=3 --backend=rust
   ```
3. **Analyze trace:**
   - Find the step where invariant became false
   - Identify the action that caused the transition
   - Extract relevant state variables at that step
4. **Determine root cause:**
   - Bug in spec logic? → Fix the spec
   - Invariant too strong? → Weaken the invariant
5. **Provide reproduction command** to the user

## Running Tests

```bash
quint test {test_file} --main={module} --match="testName"
quint test {test_file} --main={module} --match=".*"  # all tests
```

### Debugging Failed Tests

**Critical**: Quint reports errors at the test chain START (`init`), NOT where `.expect()` failed.

1. Run with `--verbosity=3`
2. Count frames — map to test code to find actual failure point
3. Check state values in last frame vs expected
4. Classify: spec bug or test bug

## Verification Checklist

Before declaring spec verified:
- [ ] `quint typecheck` passes
- [ ] All witness invariants VIOLATED (reachability confirmed)
- [ ] All safety invariants SATISFIED
- [ ] Seeds recorded for all violations
- [ ] Deterministic tests pass (if any)
- [ ] No warnings about unreachable witnesses unaddressed

## Result Classification

```
If any invariant violated:
  overall = FAIL (critical safety bug)
Else if any witness not violated:
  overall = NEEDS ATTENTION (liveness concern)
Else:
  overall = PASS
```
