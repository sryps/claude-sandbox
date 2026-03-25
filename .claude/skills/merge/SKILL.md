---
name: merge
description: Merge a branch into the current branch — detect conflicts, summarize them, and resolve them automatically where possible. Asks the user when unsure which changes to keep.
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
---

# /merge — Smart Branch Merge

Merge a specified branch into the current branch, detect conflicts, summarize them, and resolve them intelligently. When uncertain about which side to keep, ask the user.

**Arguments:** `$ARGUMENTS`

The first argument is **required** and must be the branch name to merge in.

## Steps

### 1. Validate Arguments

If `$ARGUMENTS` is empty or missing, stop immediately and tell the user:

> Usage: `/merge <branch-name>`

### 2. Pre-flight Checks

Run these commands to understand the current state:

```
git status
git branch -a
```

- Confirm the working tree is clean. If there are uncommitted changes, warn the user and ask whether to stash them before proceeding.
- Confirm the target branch (`$ARGUMENTS`) exists locally or as a remote tracking branch. If it only exists on the remote, fetch it first with `git fetch origin <branch>`.

### 3. Attempt the Merge

Start the merge without committing, so we can inspect the result:

```
git merge --no-commit --no-ff <branch>
```

If the merge completes cleanly (exit code 0, no conflicts), report success and let the user know they can review the staged changes and commit when ready:

```
git diff --cached --stat
```

Then finalize:

```
git merge --continue
```

Done — skip to step 7.

### 4. Detect and Summarize Conflicts

If the merge produced conflicts, gather information:

```
git diff --name-only --diff-filter=U
```

For each conflicted file, read the file and locate the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`). For each conflict region, summarize:

- **File** and approximate line range
- **Current branch** change: what the code does on HEAD
- **Incoming branch** change: what the code does on the merging branch
- **Nature of conflict**: e.g. both sides edited the same function, one side deleted while the other modified, divergent refactors, etc.

Present a clear summary table to the user:

```
| # | File | Lines | Current Branch | Incoming Branch | Nature |
|---|------|-------|----------------|-----------------|--------|
```

### 5. Resolve Conflicts

For each conflict, evaluate whether the resolution is clear:

**Auto-resolve when:**
- One side only has whitespace/formatting changes — keep the substantive change
- One side adds new code and the other didn't touch that area — keep the addition
- Both sides make the same logical change with slightly different code — pick the cleaner version
- One side is clearly a superset of the other (e.g. added error handling around the same code)

**Ask the user when:**
- Both sides make different substantive changes to the same logic
- A deletion on one side conflicts with a modification on the other and intent is unclear
- Business logic diverges and you cannot determine which behavior is correct
- The conflict involves configuration, environment values, or version numbers where the "right" answer depends on context

When asking, present both versions clearly and explain what each does, then ask which to keep or how to combine them.

After resolving each file, remove the conflict markers and stage the file:

```
git add <resolved-file>
```

### 6. Verify Resolution

After all conflicts are resolved:

```
git diff --cached --stat
```

Show the user a summary of all resolved files and what decisions were made. If the project has a test or build command visible in `CLAUDE.md`, `package.json`, `Makefile`, or similar, suggest running it to verify nothing broke.

### 7. Finalize

Once all conflicts are resolved and staged, complete the merge:

```
git commit --no-edit
```

Report the merge is complete and show the final state:

```
git log --oneline -5
```
