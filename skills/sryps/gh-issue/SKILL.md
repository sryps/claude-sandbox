---
name: gh-issue
description: Create a GitHub issue from a summary description. Drafts the title and body, shows a preview, and asks for confirmation before publishing.
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
---

# /gh-issue — Create GitHub Issue

Draft and create a GitHub issue from a plain-language description. Always previews before publishing.

**Arguments:** `$ARGUMENTS`

## Steps

### 1. Get Issue Description

If `$ARGUMENTS` is empty or missing, ask the user:

> What's the issue? Give me a summary and I'll draft it up.

Wait for their response before proceeding. Use their response as the issue description.

If `$ARGUMENTS` is provided, use it as the issue description.

### 2. Gather Context

Scan the codebase for relevant context that would make the issue more useful:

- Read `CLAUDE.md` if it exists for project conventions
- If the description mentions specific files, functions, or errors, look them up to include accurate references
- Check `git log --oneline -10` to see if related recent work provides context

Do NOT spend excessive time here — just enough to write a well-informed issue.

### 3. Draft the Issue

Using the user's description and any gathered context, draft:

**Title:** A concise, specific issue title (under 80 characters). Lead with the area or component if applicable (e.g. "auth: session token not refreshed on password change").

**Body:** Structure using this format:

```markdown
## Description

[Clear explanation of the problem or feature request, expanded from the user's summary]

## Context

[Any relevant details discovered from the codebase — affected files, related code, recent changes. Omit this section if there's nothing useful to add.]

## Steps to Reproduce

[If this is a bug report and reproduction steps can be inferred. Omit for feature requests or if unclear.]

## Expected Behavior

[What should happen. Omit if obvious from the description.]

## Acceptance Criteria

[Concrete conditions for this issue to be considered done. Omit for exploratory or investigative issues.]
```

Omit any sections that don't apply — don't include empty sections or force content that isn't there. Keep it focused.

### 4. Preview and Confirm

Present the drafted issue to the user in a clear preview:

```
--- Issue Preview ---

Title: <drafted title>

<drafted body>

--- End Preview ---
```

Then ask the user:

> Does this look good? I can create it as-is, or you can tell me what to change.

**Wait for the user to confirm.** Do NOT create the issue until the user explicitly approves. If the user requests changes, revise the draft and preview again.

### 5. Publish

Once the user confirms, create the issue:

```bash
gh issue create --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

Display the resulting issue URL to the user.

### 6. Labels (optional)

After creating the issue, if the user mentioned labels or if labels are obvious from the content (e.g. "bug", "enhancement"), suggest adding them:

```bash
gh issue edit <number> --add-label "<label>"
```

Only suggest — do not add labels without asking.
