---
name: docs
description: Verify documentation (README, runbooks, module docs) aligns with the actual codebase and fix any drift
allowed-tools: Bash, Read, Grep, Glob
---

# /docs — Documentation Alignment Check

Verify that documentation matches the current state of the codebase. Find and fix drift between docs and reality.

**Arguments:** `$ARGUMENTS`

## Steps

### 1. Identify documentation files

Find all documentation in the project:

```
find . -maxdepth 4 -type f \( -name "README*" -o -name "*.md" -o -name "CLAUDE.md" \) | grep -v node_modules | grep -v vendor | grep -v .git
```

Also check for:
- `docs/` directories
- Terraform module `README.md` files (often auto-generated)
- API docs, runbooks, ADRs in common locations (`docs/`, `doc/`, `adr/`)

If `$ARGUMENTS` specifies a file or path, scope the check to only that documentation.

### 2. Understand the codebase

Before checking docs, build an understanding of the current state:
- Read `CLAUDE.md` if it exists
- Check the project structure (`ls`, key config files)
- Identify the tech stack from config files (`package.json`, `Cargo.toml`, `go.mod`, `*.tf`, `Makefile`, `docker-compose.*`, etc.)
- Check available commands (`make help`, script directories, CI config)
- Read recent git history for context on what's changed lately: `git log --oneline -20`

### 3. Audit each doc for drift

For each documentation file, read it fully and cross-reference every claim against the codebase. Check for:

**Setup & installation instructions:**
- Referenced commands that no longer exist or have changed signatures
- Dependencies or tools mentioned that are no longer required (or new ones missing)
- Environment variables documented but not read by the code, or read by the code but not documented
- File paths or directory structures that have changed

**Configuration:**
- Config options documented but removed from the code
- New config options in the code with no documentation
- Default values that have changed
- Example configs that would fail with the current code

**API / CLI usage:**
- Endpoints, flags, or subcommands that no longer exist
- Changed request/response formats, required fields, or auth methods
- Example commands that would fail

**Architecture & design:**
- Component diagrams or descriptions that don't match the current module/service structure
- References to removed or renamed services, modules, or packages
- Outdated dependency or integration descriptions

**Infrastructure docs (if applicable):**
- Terraform module inputs/outputs that don't match `variables.tf` / `outputs.tf`
- Deployment steps that reference changed CI/CD pipelines or removed scripts
- Network diagrams or resource descriptions that don't match IaC definitions
- Runbook procedures referencing changed alert names, dashboards, or commands

### 4. Categorize findings

Classify each issue:

- **STALE**: Doc describes something that no longer exists or has changed
- **MISSING**: Code has functionality with no corresponding documentation
- **WRONG**: Doc actively contradicts the current code (most dangerous — misleads readers)

### 5. Fix the documentation

For each finding, update the documentation to match the code. Follow these principles:

- Match the existing style and tone of each doc — don't rewrite sections you aren't fixing
- If a section is entirely obsolete, remove it rather than leaving a stub
- For terraform modules, regenerate input/output tables from `variables.tf` and `outputs.tf`
- If you're unsure whether something was intentionally removed or is in-progress, flag it in the output rather than deleting the docs for it

### 6. Output

After making fixes, report what was found and changed:

```
## Documentation Alignment Report

### Fixed
- [STALE] README.md: removed reference to `make deploy` (replaced by CI pipeline in v2)
- [WRONG] docs/api.md: updated auth header from `X-Api-Key` to `Authorization: Bearer`
- [MISSING] README.md: added `REDIS_URL` to environment variables section

### Flagged (needs human input)
- docs/architecture.md references "notification-service" — not found in codebase, may be in a separate repo

### Summary
X issues fixed, Y flagged for review
```

### 7. Notify

Tell the user what was found and fixed. If any items were flagged for human input, highlight those.
