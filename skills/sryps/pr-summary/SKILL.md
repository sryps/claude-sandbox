---
name: pr-summary
description: Generate a PR summary from all commits since the branch diverged from a given parent branch, written to pr-summary.msg
allowed-tools: Bash, Read, Grep, Glob
---

# /pr-summary — Generate PR Summary

Analyze all commits on the current branch since it diverged from the parent branch and write a summary to `pr-summary.msg`.

**Arguments:** `$ARGUMENTS` — the parent/base branch to diff against (e.g. `main`, `dev`, `master`). This argument is **required**.

## Steps

### 1. Determine the fork point

If `$ARGUMENTS` is empty, ask the user to provide the parent branch (e.g. `/pr-summary main`). Do not assume a default.

Ensure pr-summary.msg is in the .gitignore in root of repo:

```
if [ ! -f .gitignore ] || ! grep -qF "pr-summary.msg" .gitignore; then
  echo "pr-summary.msg" >> .gitignore
fi
```

Find where the current branch forked from the provided parent branch:

```
BASE=$(git merge-base HEAD $ARGUMENTS)
```

### 2. Gather all commits since fork point

```
git log --reverse --pretty=format:"%h %s%n%b" $BASE..HEAD
```

Also run `git diff $BASE..HEAD --stat` to get a file-level change summary.

### 3. Read changed files for context

Read key changed files to understand what the commits actually do. Use `git diff $BASE..HEAD` for the full diff if needed, but focus on understanding the intent, not reciting code.

### 4. Write `pr-summary.msg`

Delete any existing `pr-summary.msg` first. Write the summary with this structure:

```
## Problems to Solve
<Describe the problems this PR addresses, based on commit messages and changed files. Focus on the "why" and "what", not the "how".>

## Summary
<1-3 bullet points describing the high-level purpose of this branch>

## Changes
<Bulleted list of specific changes, grouped logically>

## Test plan
<How to verify these changes work — mention relevant test commands, manual steps, or areas to check>
```

Keep it concise. Focus on *why* and *what*, not *how*. Group related commits into logical changes rather than listing every commit verbatim.

### 5. Open a pull request

After writing the summary, open a pull request on GitHub or your git hosting provider. 
Use the contents of `pr-summary.msg` as the PR description to provide reviewers with context and an overview of the changes.
Create the PR with `gh` CLI tool.
For example, if the current branch is `feature-branch` and the parent branch is `main`, you can run:

```
gh pr create --base main --head feature-branch --title "PR Summary" --body-file pr-summary.msg
```
