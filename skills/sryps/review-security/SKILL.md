---
name: review-security
description: Security-focused review of code and infrastructure — threat modeling, auth flow tracing, OWASP checks, IAM analysis, network exposure, secrets, dependency vulnerabilities, container hardening
allowed-tools: Bash, Read, Grep, Glob
---

# /review-security — Security Review

Review code and infrastructure changes from an adversarial perspective. Asks "what could an attacker do with this?" rather than "will this break in prod?". For production readiness checks, use `/review-prod` instead.

**Arguments:** `$ARGUMENTS`

## Steps

### 0. Understand the Security Posture

Before reviewing, read `CLAUDE.md` and scan the codebase to understand:

**General:**
- What auth mechanism is in place (middleware, JWT, OAuth, API keys, mTLS, etc.)
- What secret management approach is used (Vault, AWS Secrets Manager, sealed secrets, env vars, etc.)
- What the trust boundaries are — where does external input enter the system?

**Application (if the diff touches application source):**
- How is authentication enforced? Is it middleware-based, per-handler, or framework-provided?
- What input validation or sanitization libraries are used?
- What ORM or query mechanism is used (parameterized queries, query builders, raw SQL)?
- What serialization/deserialization is used and is it type-safe?

**Infrastructure (if the diff touches `.tf`, `Dockerfile`, `docker-compose`, Helm/K8s manifests, CI/CD configs, or cloud config):**
- What network topology is in place (VPCs, subnets, security groups, network policies)?
- What IAM structure exists (roles, service accounts, trust policies)?
- What container runtime and orchestration is used?
- What CI/CD platform runs deployments and what secrets does it have access to?

Use this understanding to determine which sections below apply. **Skip sections not relevant to the diff.**

### 1. Gather Changes

Determine what to review based on the arguments provided:

| Invocation | What to diff |
|---|---|
| `/review-security` (no args) | `git diff` + `git diff --cached` (working tree + staged) |
| `/review-security since <branch>` | `git diff $(git merge-base HEAD <branch>)..HEAD` (full feature branch) |
| `/review-security <commit-range>` | `git diff <commit-range>` (e.g. `abc123..def456`) |
| `/review-security <file-or-path>` | `git diff -- <path>` + `git diff --cached -- <path>` |

Parse `$ARGUMENTS` to determine which case applies. Read the full files for context around changed lines.

### 2. Threat Model

Before checking individual categories, briefly assess:
- What are the trust boundaries in the changed code? Where does untrusted input enter?
- What is the blast radius if this code is exploited? (data access, lateral movement, privilege escalation)
- Who are the likely threat actors? (unauthenticated users, authenticated users, compromised internal services, supply chain)

Document this briefly — it informs the severity of findings in later steps.

### 3. Authentication & Authorization
*Applies when: diff touches auth middleware, login/signup flows, token handling, session management, API handlers, or route definitions*

Check for:
- **CRITICAL**: Auth bypass — new endpoints or handlers missing auth middleware/decorators
- **CRITICAL**: Broken access control — users able to access or modify resources belonging to other users (missing ownership checks, IDOR)
- **CRITICAL**: Token/session issues — tokens that don't expire, aren't validated, or are accepted after revocation
- **CRITICAL**: Privilege escalation — paths where a lower-privilege user can gain higher privileges
- **HIGH**: Auth logic in application code rather than middleware — easy to forget on new endpoints
- **HIGH**: Missing rate limiting on auth endpoints (login, password reset, OTP verification)
- **MEDIUM**: Session fixation — session ID not rotated after authentication state change

### 4. Injection & Input Handling
*Applies when: diff touches code that processes external input — API handlers, form processing, URL parameters, file uploads, deserialization*

Check for:
- **CRITICAL**: SQL injection — string concatenation or interpolation in queries instead of parameterized queries
- **CRITICAL**: Command injection — user input passed to shell commands, `exec()`, `eval()`, `system()`
- **CRITICAL**: Server-side request forgery (SSRF) — user-controlled URLs passed to HTTP clients without allowlist validation
- **HIGH**: Path traversal — user input used in file paths without sanitization (`../` attacks)
- **HIGH**: Unsafe deserialization — deserializing untrusted data with formats that allow code execution (pickle, Java serialization, YAML `!!python/object`)
- **HIGH**: XSS — user input rendered in HTML without escaping, or `dangerouslySetInnerHTML` / equivalent with unsanitized content
- **MEDIUM**: Header injection — user input reflected in HTTP headers without newline sanitization
- **MEDIUM**: Open redirect — user-controlled redirect URLs without validation against an allowlist
- **MEDIUM**: Missing input validation at API boundaries — no limits on request body size, string length, numeric range, array size

### 5. Secrets & Credential Management

Check for:
- **CRITICAL**: Secrets (private keys, API tokens, DB passwords) hardcoded in source, config, tfvars, `docker-compose`, CI configs, or committed to git history
- **CRITICAL**: Secret references using plaintext environment variables instead of a secret manager
- **HIGH**: High-entropy strings or base64-encoded blobs in source that look like credentials
- **HIGH**: Sensitive values passed as build args or CLI flags (visible in process lists, Docker layer history)
- **HIGH**: Missing encryption-at-rest or in-transit configuration on new data stores
- **MEDIUM**: Missing rotation policy or TTL on newly created credentials or certificates
- **MEDIUM**: Overly broad secret access — services reading secrets they don't need

Also check git history for recent commits if the diff introduces secret management changes:
```
git log --all -p -S 'password\|secret\|token\|api_key' --since="1 month ago" -- ':(exclude)*.lock'
```

### 6. IAM & Access Control
*Applies when: diff touches IAM policies, roles, service accounts, trust policies, K8s RBAC, or permission boundaries*

Check for:
- **CRITICAL**: IAM policies with `Action: "*"` or `Resource: "*"` without documented scoping justification
- **CRITICAL**: Service accounts or roles with admin-level permissions (`AdministratorAccess`, `cluster-admin`, etc.)
- **CRITICAL**: Trust policies that allow assumption from overly broad principals (`*`, entire accounts without conditions)
- **HIGH**: Missing condition keys on trust policies (e.g. `aws:SourceArn`, `aws:PrincipalOrgID`, `aws:SourceIp`)
- **HIGH**: Cross-account access without explicit principal constraints
- **HIGH**: K8s ServiceAccounts with elevated RBAC that aren't needed by the workload
- **MEDIUM**: Permissions granted at a broader scope than needed (account-level vs resource-level)
- **MEDIUM**: Missing permission boundaries on roles that could create other roles

### 7. Network Exposure
*Applies when: diff touches security groups, firewall rules, NACLs, K8s NetworkPolicies, load balancers, ingress controllers, DNS records, or subnet configurations*

Check for:
- **CRITICAL**: Security groups or firewall rules with `0.0.0.0/0` ingress on non-public ports (SSH/22, databases/3306/5432/27017, internal APIs)
- **CRITICAL**: Removed or weakened network policies without justification
- **HIGH**: Missing egress restrictions on sensitive workloads (data exfiltration risk)
- **HIGH**: Databases or internal services in public subnets or with public IPs
- **HIGH**: Load balancers or ingress controllers exposing internal-only services
- **MEDIUM**: Overly broad CIDR ranges where a tighter scope is possible
- **MEDIUM**: Missing TLS termination or allowing plaintext HTTP on sensitive endpoints
- **MEDIUM**: DNS records pointing to decommissioned resources (subdomain takeover risk)

### 8. Container & Runtime Security
*Applies when: diff touches `Dockerfile`, `docker-compose`, K8s pod specs, Helm charts, or container runtime configuration*

Check for:
- **CRITICAL**: Containers running as root without justification
- **HIGH**: Excessive Linux capabilities (`SYS_ADMIN`, `NET_ADMIN`, `ALL`) without justification
- **HIGH**: Privileged mode or host namespace sharing (`hostNetwork`, `hostPID`, `hostIPC`)
- **HIGH**: Unpinned or `latest` tagged base images — no digest pinning for reproducibility and supply chain safety
- **HIGH**: Writable root filesystem when not needed (missing `readOnlyRootFilesystem: true`)
- **MEDIUM**: Missing security context — no `runAsNonRoot`, `allowPrivilegeEscalation: false`, or `seccompProfile`
- **MEDIUM**: Secrets mounted as environment variables instead of files (visible in `/proc`, logged by crash reporters)
- **MEDIUM**: Missing resource limits — can be exploited for resource exhaustion attacks

### 9. Dependency & Supply Chain
*Applies when: diff touches `package.json`, `go.mod`, `Cargo.toml`, `requirements.txt`, `Gemfile`, lockfiles, or provider/module version constraints*

Check for:
- **CRITICAL**: Dependencies added from untrusted or typosquatting-risk sources
- **HIGH**: Unpinned dependency versions (no lockfile, `*` versions, missing `~>` or `=` constraints on IaC providers/modules)
- **HIGH**: Major version bumps without review of changelog for breaking changes or security implications
- **MEDIUM**: Dependencies with known vulnerabilities — check if the project has `npm audit`, `cargo audit`, `pip-audit`, or similar configured
- **MEDIUM**: Post-install scripts in new dependencies that could execute arbitrary code
- **MEDIUM**: Removed lockfile entries without corresponding dependency removal

### 10. CI/CD Pipeline Security
*Applies when: diff touches CI/CD configs (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, etc.), deployment scripts, or build processes*

Check for:
- **CRITICAL**: Workflow injection — using `${{ github.event.*.body }}` or similar unsanitized event data in `run:` steps
- **CRITICAL**: Self-hosted runner exposure — workflows triggered by PRs from forks running on self-hosted runners with access to secrets
- **HIGH**: Overly broad secret access in CI — jobs that don't need secrets still having access to them
- **HIGH**: Missing pinning on third-party actions/orbs (using `@main` or `@v1` instead of SHA pinning)
- **MEDIUM**: Artifacts or caches that could be poisoned by earlier untrusted steps
- **MEDIUM**: Missing branch protection or approval requirements on deployment triggers

### 11. Data Exposure & Privacy
*Applies when: diff touches logging, error reporting, API responses, analytics, or data export functionality*

Check for:
- **CRITICAL**: PII or sensitive data in log output, error messages, or stack traces returned to users
- **HIGH**: API responses including more data than the client needs (over-fetching, missing field filtering)
- **HIGH**: Debug endpoints or verbose error modes that leak internal state
- **MEDIUM**: Missing audit logging on sensitive operations (data access, permission changes, deletions)
- **MEDIUM**: User data included in analytics or telemetry without consent consideration

### 12. Output

Structure output as:

```
## Security Review: [PASS | CONCERNS | CRITICAL]

### Threat Model

**Trust boundaries:** ...
**Blast radius:** ...
**Threat actors:** ...

---

### CRITICAL

(none — or findings as table below)

| # | Category | Location | Finding | Recommendation |
|---|----------|----------|---------|----------------|
| 1 | Category | file:line | Exploitation scenario and impact | Recommended fix |

---

### HIGH

| # | Category | Location | Finding | Recommendation |
|---|----------|----------|---------|----------------|
| 1 | Category | file:line | Risk description | Recommended fix |

---

### MEDIUM

| # | Category | Location | Finding | Recommendation |
|---|----------|----------|---------|----------------|
| 1 | Category | file:line | Suggested improvement | Recommended fix |

---

### Summary

X CRITICAL, Y HIGH, Z MEDIUM findings
Rating: PASS / CONCERNS / CRITICAL
```

Severity definitions:
- **CRITICAL**: Directly exploitable vulnerability or misconfiguration that could lead to unauthorized access, data breach, or privilege escalation
- **HIGH**: Security weakness that significantly increases attack surface or risk, but may require additional conditions to exploit
- **MEDIUM**: Defense-in-depth improvement or hardening recommendation

Rating logic:
- **PASS**: 0 CRITICAL, 0 HIGH, 0 MEDIUM
- **CONCERNS**: 0 CRITICAL, 1+ HIGH or MEDIUM
- **CRITICAL**: 1+ CRITICAL findings
