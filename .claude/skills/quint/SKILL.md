---
name: quint
description: Autonomous Quint formal specification workflow — generate specs (new or from codebase), typecheck, create witnesses, run invariants, and verify. Like plan mode but for formal specs.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# /quint — Quint Specification Mode

Autonomous workflow for creating and verifying Quint formal specifications. Analyzes context, generates specs, typechecks, creates witnesses, runs invariants, and iterates until verified.

**Arguments:** `$ARGUMENTS`

**Guidelines directory:** `/workspace/.claude/skills/quint/guidelines/` — read the relevant guideline file before each major step.

## Modes

Parse `$ARGUMENTS` to determine the mode:

| Argument Pattern | Mode | Description |
|---|---|---|
| `new <topic>` | **new** | Create a spec from scratch for the described topic |
| `from-code [path]` | **from-code** | Analyze existing codebase and generate a spec modeling it |
| `verify <spec_path>` | **verify** | Verify an existing `.qnt` spec (typecheck, witnesses, invariants) |
| *(empty or ambiguous)* | **ask** | Ask the user what they want to do |

If mode is **ask**, use AskUserQuestion:
- "What would you like to do?"
  - "Create a new spec from scratch" — then ask what to model
  - "Generate a spec from existing code" — then ask which code path
  - "Verify an existing spec" — then ask which `.qnt` file

---

## Steps

### 1. Gather Context

#### Mode: `new`

1. Extract the topic from `$ARGUMENTS` (everything after `new`).
2. Use AskUserQuestion: "I'll create a Quint spec for: **{topic}**. Describe the key state, operations, and safety properties you care about." Accept freeform response.
3. If the user mentions specific docs or files, read them.
4. Determine if this is a distributed/consensus protocol or a standard system — this affects which template to use.

#### Mode: `from-code`

1. Extract the path from `$ARGUMENTS` (default: current working directory).
2. Scan the codebase for modelable components:
   ```
   Glob: **/*.rs, **/*.go, **/*.ts, **/*.py, **/*.sol (pick what exists)
   ```
3. Read key files — focus on: type/struct definitions, enums, state management, protocol logic, assertions/invariants in code.
4. Grep for state machine patterns: `enum.*State`, `phase`, `round`, `step`, `transition`, `match.*state`.
5. Identify what to model: data structures, state transitions, invariants implied by assertions/checks in the code.
6. Use AskUserQuestion: "I found these modelable components: {list}. Which should I focus the spec on?" Let the user pick or refine.

#### Mode: `verify`

1. Read the spec file at the provided path.
2. Extract: module name, state variables, actions, existing invariants, const parameters.
3. Skip directly to Step 3 (Typecheck).

---

### 2. Plan and Generate the Specification (modes: new, from-code)

**Before writing any Quint code**, read these guideline files:

```
Read /workspace/.claude/skills/quint/guidelines/language-constraints.md
Read /workspace/.claude/skills/quint/guidelines/quint-syntax.md
```

Then read the appropriate template:
- For standard systems (state machines, smart contracts, algorithms):
  ```
  Read /workspace/.claude/skills/quint/guidelines/spec-template.md
  ```
- For distributed/consensus protocols (BFT, message-passing, multi-node):
  ```
  Read /workspace/.claude/skills/quint/guidelines/choreo-template.md
  ```

**Then read a relevant example spec** to ground your code in real working Quint. Pick based on topic:

| Topic | Example to Read |
|---|---|
| Consensus / BFT / distributed | `/workspace/.claude/skills/quint/guidelines/examples/consensus.qnt` + `two_phase_commit.qnt` |
| Distributed with Choreo framework | `/workspace/.claude/skills/quint/guidelines/examples/two_phase_commit_choreo.qnt` |
| DeFi / tokens / smart contracts | `/workspace/.claude/skills/quint/guidelines/examples/coin.qnt` + `erc20.qnt` |
| Finance / blockchain / multi-asset | `/workspace/.claude/skills/quint/guidelines/examples/bank.qnt` |
| State machines / games / turn-based | `/workspace/.claude/skills/quint/guidelines/examples/tictactoe.qnt` |
| Simple / puzzles / logic | `/workspace/.claude/skills/quint/guidelines/examples/prisoners.qnt` |
| General / unsure | `/workspace/.claude/skills/quint/guidelines/examples/coin.qnt` (best all-around pattern demo) |

If you need to look up a specific Quint operator's signature, read `/workspace/.claude/skills/quint/guidelines/builtins.md`.

#### 2a. Plan the Spec

Output a brief plan:

```
Spec Plan: {ModuleName}
  Template:   standard | choreo
  Types:      {list of types to define}
  State vars: {list of state variables with types}
  Actions:    init, {list of domain actions}, step
  Invariants: {list of safety properties to check}
  Witnesses:  {list of reachability goals}
```

Use AskUserQuestion: "Here's the spec plan. Proceed, or adjust?" Options: "Proceed" / "Let me adjust" (freeform).

#### 2b. Write the Spec

Generate the `.qnt` file. Default path: `specs/{module_name_lowercase}.qnt`. Create `specs/` directory if needed.

Follow the template from the guideline file you read. Apply patterns exactly — the State Type pattern (encapsulate state, pure functions, thin actions) is mandatory for standard specs.

---

### 3. Typecheck

**Before debugging errors**, read:
```
Read /workspace/.claude/skills/quint/guidelines/error-handling.md
```

Run:
```bash
quint typecheck {spec_path}
```

If it fails:
1. Read the error carefully.
2. Check against language constraints and common error patterns from the error-handling guideline.
3. Fix the spec with the Edit tool and re-typecheck.
4. Iterate up to 5 times.
5. If still failing after 5 attempts, show the error to the user and ask for guidance.

If it passes, proceed.

---

### 4. Generate and Run Witnesses

**Before generating witnesses**, read:
```
Read /workspace/.claude/skills/quint/guidelines/verification.md
```

Witnesses are negated goals that prove reachability via simulation. A **VIOLATED** witness is **GOOD** — it means the scenario is reachable.

#### 4a. Detect Witness Goals

Read the spec and identify interesting scenarios per the verification guideline:
- Phase/round progression
- Message type appearance (for each variant in a sum type)
- Quorum/majority formation
- Timeout triggers
- Terminal states (decisions, commitments)
- State variable changes (booleans, sets, counters)
- Multiple actors taking actions

#### 4b. Write the Witness File

Write to `{spec_dir}/{spec_name}_witnesses.qnt`. If the spec is parameterized (has `const` declarations), instantiate with concrete values in the import.

#### 4c. Typecheck the Witness File

```bash
quint typecheck {witness_file}
```

Fix errors iteratively (up to 5 attempts).

#### 4d. Run Each Witness

For each witness invariant, run:
```bash
quint run {witness_file} --main={witness_module} --invariant={witness_name} --max-steps=100 --max-samples=100 --backend=rust
```

Interpret results per the verification guideline. Use progressive increase for stubborn witnesses.

---

### 5. Run Invariants

For each invariant defined in the spec (or witness module), run:
```bash
quint run {file} --main={module} --invariant={invariant_name} --max-steps=200 --max-samples=500 --backend=rust
```

Interpret results per the verification guideline. For violations, extract seed and provide reproduction command.

---

### 6. Report and Iterate

#### Present Summary

```
Quint Verification Summary
==========================
Spec: {spec_path}
Module: {module_name}

Typecheck: PASS

Witnesses: {violated}/{total} reachable
  [PASS] {name} — violated at step N
  [WARN] {name} — not violated (may be unreachable)

Invariants: {satisfied}/{total} hold
  [PASS] {name} — satisfied
  [FAIL] {name} — VIOLATED (seed: 0x...)

Verdict: {PASS | FAIL | NEEDS ATTENTION}
```

#### If Verdict is FAIL or NEEDS ATTENTION

Use AskUserQuestion: "Verification found issues. What would you like to do?"
- "Fix the spec" — analyze the violation trace (`--verbosity=3`), propose a fix, apply it, re-run from Step 3
- "Fix the witnesses" — adjust witness definitions that are too strong or malformed
- "Increase simulation budget" — re-run with higher `--max-steps` and `--max-samples`
- "Accept as-is" — stop and report final state

If the user chooses to fix, iterate: fix, typecheck, re-run witnesses and invariants. Limit to 3 full iterations before asking for further direction.

#### If Verdict is PASS

Report success and suggest next steps.

---

## Error Handling

- **quint not installed**: If `quint typecheck` fails with "command not found", tell the user: "Quint CLI not found. Install with: `npm i @informalsystems/quint -g`"
- **Spec file not found**: Ask the user for the correct path.
- **All witnesses satisfied**: Major concern — spec may be vacuous or over-constrained. Alert the user.
- **All invariants violated**: Critical — spec likely has fundamental design bugs. Alert the user.
