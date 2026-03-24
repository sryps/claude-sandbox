---
name: runbook
description: Generate or update an operational runbook for a service or component — deployment, rollback, health checks, failure modes, escalation. Outputs to docs/ by default.
allowed-tools: Bash, Read, Grep, Glob
---

# /runbook — Generate Operational Runbook

Generate or update a runbook for a service or component by reading the actual code, IaC, and CI/CD configs.

**Arguments:** `$ARGUMENTS` — the service, component, or module to document (e.g. `api-server`, `worker`, `modules/vpc`, `infra/rds`). Optionally specify output path (defaults to `docs/runbooks/`).

## Steps

### 1. Parse arguments

If `$ARGUMENTS` is empty, ask the user what service or component to create a runbook for.

If the argument contains a path separator, treat it as a directory to examine. Otherwise, search the codebase for a matching service, module, or component.

Determine the output path:
- Default: `docs/runbooks/<component-name>.md`
- If the user provided an explicit output path, use that instead
- Create the output directory if it doesn't exist

### 2. Understand the component

Read `CLAUDE.md` if it exists, then investigate the target component thoroughly:

**Service/application components:**
- Entry point and main configuration files
- Environment variables it reads (grep for `os.Getenv`, `process.env`, `os.environ`, `env::var`, etc.)
- External dependencies — databases, caches, queues, other services it calls
- Ports it listens on
- Health check endpoints (grep for `/health`, `/ready`, `/live`, `/status`)

**Infrastructure components:**
- Terraform/IaC resource definitions and what they provision
- Input variables and outputs
- Dependencies on other modules or remote state
- State file location and backend config

**For both:**
- CI/CD pipeline config — how is this deployed? What stages, approvals, or gates exist?
- Dockerfile or container config if present
- Deployment manifests (K8s, Helm, docker-compose, ECS task definitions)
- Monitoring — grep for alert definitions, dashboard references, metric names

### 3. Check for existing runbook

Check if a runbook already exists at the output path. If it does, read it — you'll be updating rather than rewriting. Preserve any manually-added sections (on-call notes, incident history, tribal knowledge) that aren't derivable from the code.

### 4. Write the runbook

Write or update the runbook with the following structure. **Only include sections that are relevant to the component** — skip sections that don't apply.

```markdown
# <Component Name> Runbook

> Auto-generated from codebase. Last updated: <date>.
> Verify commands before running in production.

## Overview
What this component does, in 2-3 sentences. What depends on it and what it depends on.

## Configuration

### Environment Variables
| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| ... | ... | ... | ... |

### Key Config Files
- `path/to/config` — what it controls

## Deployment

### How to deploy
Step-by-step deployment process derived from CI/CD config and deployment manifests.

### How to rollback
Specific rollback steps — git revert + redeploy, terraform apply previous state, helm rollback, etc.

### Pre-deployment checks
What to verify before deploying (migrations pending, dependency availability, feature flags).

## Health & Monitoring

### Health checks
- Endpoint: `GET /health` — what it verifies
- How to check manually: `curl ...`

### Key metrics & dashboards
Metric names, dashboard links, and what normal looks like.

### Alerts
| Alert | Meaning | Action |
|-------|---------|--------|
| ... | ... | ... |

## Common Failure Modes

### <Failure scenario>
- **Symptoms**: What you'd see in logs/metrics/alerts
- **Cause**: What typically causes this
- **Resolution**: Step-by-step fix
- **Prevention**: How to avoid recurrence

(Repeat for each failure mode identified from error handling paths, retry logic, circuit breakers, etc.)

## Dependencies

### Upstream (this component depends on)
| Dependency | Type | What happens if it's down |
|------------|------|---------------------------|
| ... | DB/API/Cache/Queue | ... |

### Downstream (depends on this component)
| Consumer | Impact if this component is down |
|----------|----------------------------------|
| ... | ... |

## Operational Commands

### Useful commands
```bash
# Check logs
<actual command derived from deployment setup>

# Connect to database
<if applicable>

# Restart service
<actual command>
```

### Terraform operations (if IaC component)
```bash
# Plan changes
terraform plan -target=module.<name>

# Apply with approval
terraform apply -target=module.<name>

# Check state
terraform state list | grep <name>
```

## Escalation
Who owns this component, how to reach them, when to escalate.
```

### 5. Verify accuracy

After writing, cross-reference key claims against the codebase:
- Do the environment variables listed actually exist in the code?
- Do the health check endpoints exist?
- Do the deployment commands match the CI/CD config?
- Do the file paths referenced actually exist?

Fix any inaccuracies found.

### 6. Notify

Tell the user the runbook location and highlight:
- Any sections that need manual input (escalation contacts, dashboard URLs, on-call info)
- Any assumptions made that should be verified
- If updating an existing runbook, what sections changed
