---
name: chase-ci
description: Monitor PR CI checks, statuses, and comments (including bot review comments) in a loop using gh; fetch logs for failures, remediate, push fixes, and resume monitoring. Use when asked to chase CI, watch PR checks, or when asked to push with no followup tasks.
---

# Chase CI

## Overview

Monitor PR checks and comments on a fixed cadence (default 5 minutes). Stay silent while monitoring unless a failure needs remediation or user input.

## Workflow

### 1) Identify the PR

- Default to the currently checked out branch.
- Example:
  - `gh pr view --json number,url,headRefName`

### 2) Start the monitoring loop

- Poll checks and statuses:
  - `gh pr checks <pr-number>`
  - `gh pr view <pr-number> --json statusCheckRollup`
- Poll comments (include bot review comments):
  - `gh pr view <pr-number> --comments`
- Track the last seen comment (timestamp or id) in memory and only react to new user/bot comments.
- Sleep 5 minutes between polls. If tool sleep is capped (e.g., 30s), loop shorter sleeps to reach 5 minutes.

### 3) On failure

- Identify failing checks and collect their URLs.
- Pull logs:
  - `gh run view <run-id> --log-failed`
  - If needed: `gh run view <run-id> --job <job-id> --log | rg "error TS|FAIL|Error"`
- Diagnose and apply the minimal fix in the working directory.
- Run targeted checks only if needed. Avoid running local typecheck scripts; inspect the CI typecheck logs instead.
- Commit and push (no amend), then restart monitoring from step 1.

## Completion Criteria

- Consider CI successful when only `XXXX Review Status` remains pending (it waits on human reviewers).

## Guardrails

- Do not send user messages while monitoring; only speak if you need user input/approval or to report a blocking failure.
- Keep the loop at 5 minutes unless instructed otherwise.
- Prefer targeted tests over full suites.
- Use the repo root as the working directory.
