# Claude Code Docker Environment

A containerized development environment for Claude Code. Drop in your project, get an isolated container with languages, tools, and drag-and-drop Claude skills ready to go.

## Drag-and-Drop Claude Skills

This repo ships a library of reusable Claude skills in `skills/sryps/`. When you `make run`, each skill is automatically mounted into your project's `.claude/skills/` directory (skipping any that already exist in your project). Claude picks them up immediately — no configuration needed.

| Skill | Description |
|-------|-------------|
| `/commit` | Write a commit message following project conventions |
| `/pr-summary` | Generate a PR summary from branch commits |
| `/merge` | Merge a branch, detect conflicts, and resolve them |
| `/review-prod` | Review code for production readiness |
| `/review-security` | Security-focused code and infrastructure review |
| `/docs` | Verify documentation aligns with codebase and fix drift |
| `/runbook` | Generate operational runbooks for services |
| `/quint` | Autonomous Quint formal specification workflow |

To add your own skills, create a `SKILL.md` in `skills/sryps/<skill-name>/` and it will be mounted into every new container.

## What's in the Container

| Category | Tools |
|----------|-------|
| Languages | Go 1.24, Python 3 (pip, venv), Rust (stable via rustup), Node.js 20, TypeScript |
| Infrastructure | Terraform, Ansible, Docker CLI |
| Dev Tools | git, gh (GitHub CLI), protobuf-compiler, clang, llvm, pkg-config |
| Utilities | curl, wget, jq, tree, openssl, net-tools, dnsutils |
| Rust Tools | taplo (TOML formatter/linter), rust-analyzer (LSP) |
| Node Tools | Claude Code CLI, Quint (formal specification) |

Base image: `debian:trixie-slim`. Runs as non-root user `dev`.

## Quick Start

```bash
# Build the image
make build

# Run — prompts for project path, container name, then drops you into Claude
make run
```

That's it. `make run` handles everything:

1. Prompts for your project directory
2. Prompts for a container name
3. Asks whether to skip permission prompts
4. Mounts your project + skills into the container
5. Configures git identity and GitHub access (if `GH_TOKEN` is set)
6. Launches Claude Code
7. Cleans up the container when you exit

## GitHub Access

Copy `.env.example` to `.env` and set your token to enable `git push`, `gh pr create`, etc. inside the container:

```
GH_TOKEN=ghp_your_token_here
GIT_USER_NAME=Your Name
GIT_USER_EMAIL=you@example.com
```

## License

This project configuration is provided as-is for development purposes.
