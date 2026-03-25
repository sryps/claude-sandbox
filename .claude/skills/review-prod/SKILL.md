---
name: review-prod
description: Review code and infrastructure for production readiness — error handling, observability, concurrency, stability, data integrity, IaC safety, test coverage, hygiene. For security-focused review use /review-security instead.
allowed-tools: Bash, Read, Grep, Glob
---

# /review-prod — Production Readiness Review

Review code changes for production readiness. Assigns an overall rating and per-finding severity.

**Arguments:** `$ARGUMENTS`

## Steps

### 0. Understand Project Conventions

Before reviewing, read `CLAUDE.md` and scan the codebase to understand the project's conventions and classify the project type:

**General conventions (all projects):**
- What logging/tracing framework is used and its idiomatic patterns
- What auth mechanism is in place (middleware, token validation, etc.)
- What error handling idioms the project follows

**Application code conventions (if the diff touches application source):**
- What ORM or database query approach is used (parameterized queries, query builders, etc.)
- What inter-service communication patterns exist and how they are authenticated

**Infrastructure conventions (if the diff touches `.tf`, `Dockerfile`, `docker-compose`, Helm/K8s manifests, CI/CD configs, or cloud config):**
- What IaC tool and version constraints are used (Terraform, Pulumi, CloudFormation, etc.)
- What cloud provider(s) and what naming/tagging conventions exist
- What CI/CD platform runs deployments and what guardrails exist (plan approval, drift detection)

Use this understanding to determine which review sections below are applicable. **Skip sections that are not relevant to the changes in the diff.**

### 1. Gather Changes

Determine what to review based on the arguments provided:

| Invocation | What to diff |
|---|---|
| `/review-prod` (no args) | `git diff` + `git diff --cached` (working tree + staged) |
| `/review-prod since <branch>` | `git diff $(git merge-base HEAD <branch>)..HEAD` (full feature branch) |
| `/review-prod <commit-range>` | `git diff <commit-range>` (e.g. `abc123..def456`) |
| `/review-prod <file-or-path>` | `git diff -- <path>` + `git diff --cached -- <path>` |

Parse `$ARGUMENTS` to determine which case applies. If the arguments don't clearly match any pattern, treat them as a git ref or path and try the most reasonable interpretation.

Read the full files for context around changed lines.

### 2. Error Handling
*Applies when: diff touches application source code*

Check for:
- **BLOCK**: Unhandled errors on fallible operations (network, DB, parsing, file I/O) — e.g. bare `.unwrap()` in Rust, uncaught exceptions in Python/JS, ignored `err` in Go
- **BLOCK**: Silent default values used as a safety net to hide missing data (e.g. `unwrap_or_default()`, `|| {}`, `?? ""` where the default masks a bug)
- **BLOCK**: Swallowed errors — discarding error returns or catching exceptions with no handling or propagation
- **WARN**: Missing error context — low-level errors should be wrapped with domain meaning before propagation
- **WARN**: Panic/crash paths without descriptive messages explaining the invariant

### 3. Logging & Observability

Check against the project's logging/tracing conventions (discovered in step 0):
- **WARN**: Missing log/trace output on error paths — every error return should be observable
- **WARN**: Wrong severity level — routine ops vs recoverable errors vs failures requiring attention
- **WARN**: Unstructured log messages — prefer the project's structured logging idiom over string interpolation
- **BLOCK**: Sensitive data in logs — private keys, secrets, tokens, plaintext credentials

### 4. Concurrency & Async
*Applies when: diff touches code with async runtimes, threading, or shared mutable state*

Check for:
- **BLOCK**: Blocking calls (synchronous I/O, CPU-heavy computation, thread sleep) inside async contexts without offloading to a blocking thread pool
- **BLOCK**: Shared mutable state accessed without synchronization (missing locks, atomics, or channel-based patterns)
- **WARN**: Lock held across await points — can cause deadlocks or excessive contention
- **WARN**: Missing cancellation safety — resources that leak or corrupt state if a future is dropped mid-execution

### 5. Stability
*Applies when: diff touches application services, API handlers, or background workers*

Check for:
- **WARN**: Network calls without timeouts — HTTP clients should have explicit timeout configuration
- **WARN**: Retries without backoff — retry loops should use exponential backoff or at minimum a delay
- **WARN**: Missing graceful shutdown handling for long-running services
- **BLOCK**: DB operations outside transactions when atomicity is required (multi-table writes, state transitions)
- **WARN**: Unbounded collections grown from external input without size limits

### 6. Security (surface-level only)

Flag only the most obvious security issues. For a thorough security review, use `/review-security`.

- **BLOCK**: Secrets (private keys, API tokens, DB passwords) hardcoded in source, config, or log output
- **BLOCK**: Sensitive data in logs — tokens, credentials, PII
- **WARN**: Any other security concern that is immediately obvious from the diff — note it briefly and recommend running `/review-security`

### 7. Data Integrity
*Applies when: diff touches database schemas, migrations, serialization, or state machines*

Check for:
- **BLOCK**: Schema migrations that are destructive without a data migration plan (dropping columns/tables that contain production data)
- **BLOCK**: State machine transitions that skip required intermediate states or validation
- **WARN**: New fields without default values or migration backfill for existing rows
- **WARN**: Changes to serialization formats (JSON field names, wire protocol) without versioning or backwards compatibility consideration

### 8. Test Coverage

Check for:
- **WARN**: New code paths (handlers, state transitions, business logic branches) with no corresponding test
- **WARN**: Changed behavior without updated tests — existing tests may pass but no longer exercise the new logic
- **BLOCK**: Removed or weakened test assertions (e.g. removing error-case tests, loosening expected values)

### 9. IaC & Provider Hygiene
*Applies when: diff touches `.tf` files, Terraform modules, Pulumi programs, CloudFormation templates, or similar IaC*

Check for:
- **BLOCK**: Unpinned provider or module versions (no `~>` or `=` constraint)
- **WARN**: Major version bumps on providers or modules without changelog review
- **WARN**: Inline resources that should be extracted to shared modules for consistency with existing patterns
- **WARN**: Missing required resource tags per the project's tagging conventions

### 10. Infrastructure State & Blast Radius
*Applies when: diff touches IaC that manages stateful resources (databases, storage, DNS, load balancers) or modifies terraform state operations*

Check for:
- **BLOCK**: Removing `prevent_destroy` lifecycle on stateful resources (RDS, S3 buckets with data, persistent volumes)
- **BLOCK**: `terraform state rm` or manual state manipulation without documented reason
- **WARN**: Changes that force resource replacement (destroy + recreate) on stateful infrastructure — flag for plan review
- **WARN**: Missing `create_before_destroy` lifecycle on zero-downtime resources (load balancers, DNS records, ASGs)
- **WARN**: Resources that should be imported but are being recreated (data loss risk)
- **WARN**: Broad `moved` or `import` blocks that affect many resources at once

### 11. Code Hygiene

Check for:
- **WARN**: `TODO` or `FIXME` comments left in production code
- **WARN**: Commented-out code blocks
- **BLOCK**: Debug print statements (e.g. `dbg!()`, `println!()`, `console.log()`) in non-CLI code
- **WARN**: Lint suppressions that hide real warnings

### 12. Output

Structure output as:

```
## Production Readiness: [READY | NEEDS CHANGES | BLOCK]

---

### BLOCK

(none — or findings as table below)

| # | Category | Location | Finding | Recommendation |
|---|----------|----------|---------|----------------|
| 1 | Category | file:line | Why this blocks | Recommended fix |

---

### WARN

| # | Category | Location | Finding | Recommendation |
|---|----------|----------|---------|----------------|
| 1 | Category | file:line | Risk description | Suggested fix |

---

### Summary

X BLOCK items, Y WARN items
Rating: READY / NEEDS CHANGES / BLOCK
```

Rating logic:
- **READY**: 0 BLOCK, 0 WARN
- **NEEDS CHANGES**: 0 BLOCK, 1+ WARN
- **BLOCK**: 1+ BLOCK items
