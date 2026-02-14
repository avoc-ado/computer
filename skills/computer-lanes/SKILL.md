---
name: computer-lanes
description: Use the computer harness for multi-lane Codex workflows with explicit lane/task ownership, terminal title discipline, and lane-selected worktree setup. Use when running p1/p2/p3+ parallel agents and tracking who is doing what.
---

# computer-lanes

## Purpose
Use the `computer` shell harness as the default multi-lane Codex workflow.

This skill standardizes lane + task ownership so terminal titles stay clear while running multiple long-lived agents.

## Required Harness
Load the harness in shell startup:

```bash
source /Users/tristyn/repos/computer/computer.sh
```

## Operator Commands
- `p1` .. `p10`: select lane/profile (this now sets up that lane worktree automatically)
- `lane pN`: select lane/profile generically
- `c`: launch codex wrapper
- `sz`: re-source `~/.zshrc`

## Agent Command Scope
Agents using this skill should only call:
- `task "<title>"`
- `task`
- `task --clear`

Agents should not call lane-selection commands (`pN` / `lane`) unless explicitly asked.

## Worktree Setup Rule
Lane selection (`pN`) is responsible for worktree setup/bootstrap for that lane.

When a lane is selected, the harness:
1. Ensures `.worktree/pN` exists.
2. Ensures lane env file exists (`.env.codex.pN`).
3. Runs repo-appropriate setup/install for that worktree.
4. Optionally switches cwd into that lane worktree.
5. Starts Codex with `--add-dir <repo-root>` so root-only files remain writable from lane cwd.

Agent expectation in this mode:
- Work in the current lane worktree cwd.
- Assume setup is already handled by lane selection.
- Only set/update task ownership with `task "..."`.

## Title Contract
Terminal title format is always:

```text
p<lane>; <task>
```

If task is unset, fallback title is `p<lane>; no-task`.

## Agent Behavior Rules
1. During open discussion, do not force a task title.
2. As soon as a concrete actionable task emerges, set task immediately:
   - Run `task "<short 3-8 word title>"`.
3. If scope materially changes, update task title with another `task "..."` command.
4. Keep titles concise and action-oriented (avoid vague labels like `misc` or `debug`).

## Quick Flow
```bash
# operator
p5
c

# discussion happens

# agent
task "startup readiness checks"
# continue execution
```

## VS Code Requirement
For title updates to render in VS Code terminal tabs, set:

```json
"terminal.integrated.tabs.title": "${sequence}"
```

## Chrome MCP Focus Policy
When using Chrome MCP, avoid commands that foreground Chrome on macOS.

Rules:
1. Use `navigate_page` as the default for opening a URL.
2. Treat `new_page` as foregrounding behavior and avoid it unless the user explicitly asks for a new tab/page.
3. If the user asks to avoid bringing Chrome to front, only use `navigate_page`.

## Frontend Refresh Rule
For React, Next.js, and React Native development, perform a full page/app refresh after code changes when validating behavior.

Reason:
- Hot module reloading can enter a hard-error state during half-edited code/runtime error windows, and the HMR retry path may not recover cleanly without a full refresh.
