---
name: commit
description: Write a commit message following the project template and save it to commit.msg
allowed-tools: Bash, Read, Grep, Glob
---

# /commit — Write Commit Message

Examine changes and write a commit message to `commit.msg` following the project's commit message template.

## Steps

### 1. Delete any existing commit.msg

```
rm -f commit.msg
```

ensure commit.msg is in the .gitignore in root of repo:

```
if [ ! -f .gitignore ] || ! grep -qF "commit.msg" .gitignore; then
  echo "commit.msg" >> .gitignore
fi
```

### 2. Examine changes

Run these commands to understand what's being committed:

```
git status
git diff
git diff --cached
git log --oneline -10
```

Look at both staged and unstaged changes. Read changed files for context if needed.

### 3. Write commit.msg

Write the commit message to `commit.msg` using this template:

```
[First line gives a top level commit message in 100 chars or less]

## Problems to Solve
[What problems is this commit trying to solve?]

## Plan
[What will you work on this iteration? Why?]

## Work Log
[Fill this in as you work]

## Summary
[Fill this in before committing. Give an overview of what you accomplished, or to pass forward context and priorities if there is still work to do on your current task.]
```

**Guidelines:**
- Aim for about 50 lines total
- For extremely small and simple commits, use an abbreviated format with only the first line and the summary
- You may be writing a message for work you didn't perform yourself — examine the changes carefully and fill it in as best you can

### 4. Push the commit message

Once you have written the commit message, you can stage your changes and commit using the message from `commit.msg`, then push to the remote repository:

```
git add .
git commit -F commit.msg
git push
```

