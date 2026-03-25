---
name: pr-review
description: Thorough peer code review of a PR or branch — correctness, bugs, logic errors, edge cases, code quality, simplicity, naming, test coverage. Takes a PR number or base branch argument. Pulls PR metadata via gh if available.
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
---

# /pr-review — Peer Code Review

Perform a thorough code review as if you are a developer peer-reviewing a pull request for correctness, bugs, quality, and simplicity.

**Arguments:** `$ARGUMENTS`

## Steps

### 1. Parse Arguments & Determine Branches

**An argument is required.** If `$ARGUMENTS` is empty or missing, stop immediately and tell the user:

> Usage: `/pr-review <PR-number>` or `/pr-review <base-branch>`
>
> Examples:
> - `/pr-review 42` — review PR #42
> - `/pr-review main` — review current branch against `main`

Do NOT proceed without an argument. Do NOT attempt to auto-detect a PR from the current branch.

The argument must be one of:

| Invocation | Behavior |
|---|---|
| `/pr-review #123` or `/pr-review 123` | Fetch PR #123 via `gh`. Extract base branch, head branch, and all metadata from the PR. If the head branch is not checked out locally, fetch it. |
| `/pr-review main` | Use `main` as the base branch. Use the current branch as the head branch. Do NOT look up a PR — just diff against the base branch. |

### 2. Gather Context

#### If argument is a PR number:

Fetch PR metadata via `gh`:

```bash
gh pr view <number> --json title,body,number,url,labels,author,reviews,comments,additions,deletions,changedFiles,baseRefName,headRefName
```

Extract and display:
- PR title, number, URL
- Author
- Base branch and head branch
- Labels
- PR description/body (use this for additional context on intent)
- Stats (additions, deletions, changed files)
- Any existing review comments (to avoid duplicating feedback already given)

If the head branch is not checked out locally:
- Fetch the head branch: `git fetch origin <headRefName>`
- Use `origin/<headRefName>` as the head ref for diffing (do NOT check it out — stay on the current branch)

Then gather the diff:

```bash
git diff $(git merge-base <head-ref> <base-branch>)..<head-ref>
git diff $(git merge-base <head-ref> <base-branch>)..<head-ref> --stat
git log $(git merge-base <head-ref> <base-branch>)..<head-ref> --oneline
```

Where `<head-ref>` is `origin/<headRefName>` if not checked out, or `HEAD` if the head branch is the current branch.

#### If argument is a branch name:

Use the argument as the base branch and the current branch as the head. Do NOT call `gh` or look up any PR.

Gather the diff:

```bash
git diff $(git merge-base HEAD <base-branch>)..HEAD
git diff $(git merge-base HEAD <base-branch>)..HEAD --stat
git log $(git merge-base HEAD <base-branch>)..HEAD --oneline
```

#### In both cases:

Read the full content of every changed file to understand the complete context around the changes, not just the diff hunks.

### 3. Understand Project Conventions

Before reviewing, read `CLAUDE.md` (if it exists) and scan nearby code to understand:
- Language idioms and style conventions
- Error handling patterns
- Testing patterns and frameworks
- Naming conventions
- Project structure and architecture

This context is essential — do not flag things that follow established project conventions.

### 4. Review: Correctness & Bugs

This is the most important section. Review every change for:

- **BLOCK**: Logic errors — conditions that are inverted, off-by-one errors, wrong comparisons, incorrect boolean logic
- **BLOCK**: Null/nil/undefined dereferences — accessing properties on values that could be absent
- **BLOCK**: Race conditions — shared state accessed without synchronization, TOCTOU bugs
- **BLOCK**: Resource leaks — opened files/connections/handles that are never closed, missing cleanup in error paths
- **BLOCK**: Incorrect API usage — calling functions with wrong argument types, wrong argument order, misunderstanding return values
- **BLOCK**: Missing error handling — fallible operations where errors are ignored or silently swallowed
- **BLOCK**: Boundary errors — integer overflow, buffer overruns, out-of-bounds access, truncation
- **WARN**: Unhandled edge cases — empty inputs, zero values, negative numbers, very large inputs, unicode, concurrent modifications
- **WARN**: Incorrect assumptions documented in comments that don't match the code

### 5. Review: Code Quality & Clarity

- **WARN**: Overly complex code — deeply nested conditionals, long functions doing too many things, convoluted control flow that could be simplified
- **WARN**: Poor naming — variables, functions, or types with misleading or unclear names
- **WARN**: Code duplication — repeated logic that should be extracted (only if there are 3+ repetitions or the duplication is likely to cause maintenance bugs)
- **WARN**: Dead code — unreachable branches, unused variables, commented-out code left behind
- **WARN**: Inconsistency with surrounding code style — different patterns used in the same file or module for the same kind of operation
- **NIT**: Minor style issues — formatting inconsistencies, import ordering, unnecessary type annotations (only mention if genuinely distracting)

### 6. Review: Design & Simplicity

- **WARN**: Over-engineering — abstractions, indirection, or generalization that isn't justified by current requirements
- **WARN**: Wrong level of abstraction — too much or too little encapsulation for the problem being solved
- **WARN**: Leaky abstractions — implementation details exposed through interfaces that should hide them
- **BLOCK**: Breaking API contracts — changes to public interfaces, serialization formats, or database schemas without migration or versioning
- **WARN**: Missing validation at system boundaries — user input, external API responses, file contents

### 7. Review: Test Coverage

- **WARN**: New behavior added without corresponding tests
- **WARN**: Changed behavior where existing tests were not updated to cover the new logic
- **BLOCK**: Tests removed or assertions weakened without clear justification
- **WARN**: Tests that don't actually test what they claim (e.g. asserting on mocks instead of behavior, tautological assertions)
- **WARN**: Missing edge case tests for complex logic (empty inputs, error paths, boundary values)

### 8. Review: Security (surface-level)

Flag only clearly visible security issues. For a thorough security review, recommend `/review-security`.

- **BLOCK**: Hardcoded secrets, API keys, tokens, or credentials
- **BLOCK**: SQL injection, command injection, or path traversal from unsanitized input
- **BLOCK**: Sensitive data logged or exposed in error messages
- **WARN**: Missing authentication or authorization checks on new endpoints
- **WARN**: Any other obvious security concern — note it briefly and recommend `/review-security`

### 9. Review: Performance (only if obvious)

Only flag performance issues that are clearly problematic, not speculative optimization opportunities.

- **WARN**: N+1 queries — database queries inside loops
- **WARN**: Unbounded growth — collections that grow without limit from external input
- **WARN**: Unnecessary work — repeated expensive computations that could be cached, loading entire datasets when only a subset is needed
- **BLOCK**: Algorithmic complexity issues — O(n^2) or worse on potentially large inputs when a better approach is straightforward

### 10. Output

Structure the output as:

```
## PR Review: [APPROVE | REQUEST CHANGES | BLOCK]

> PR #<number>: <title> (if PR metadata was available)
> <url>
> Author: <author> | +<additions> -<deletions> | <changedFiles> files

---

### BLOCK

(none — or findings as table below)

| # | Category | Location | Finding | Suggestion |
|---|----------|----------|---------|------------|
| 1 | Category | file:line | What's wrong and why | How to fix it |

---

### WARN

| # | Category | Location | Finding | Suggestion |
|---|----------|----------|---------|------------|
| 1 | Category | file:line | Concern description | Suggested improvement |

---

### NIT

| # | Finding | Location |
|---|---------|----------|
| 1 | Minor issue | file:line |

---

### What looks good

Briefly call out 2-3 things the author did well (good test coverage, clean abstractions, thoughtful error handling, etc.). Peer review should acknowledge good work, not just find problems.

---

### Summary

X BLOCK, Y WARN, Z NIT
Verdict: APPROVE / REQUEST CHANGES / BLOCK
```

Verdict logic:
- **APPROVE**: 0 BLOCK, 0 WARN (NITs are fine)
- **REQUEST CHANGES**: 0 BLOCK, 1+ WARN
- **BLOCK**: 1+ BLOCK items

### 11. Offer Next Steps

After the review, suggest relevant follow-up actions:

- If there are security concerns: "Run `/review-security` for a thorough security audit."
- If there are production readiness concerns: "Run `/review-prod` for a production readiness check."
- If the review is clean: "This looks good to merge into `<base-branch>`."
