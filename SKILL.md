---
name: spawn-session
description: Spawn an independent, top-level user conversation session in the left sidebar that works in parallel and reports back to this chat.
---

# Spawn session

This skill allows an agent to programmatically spawn a genuine, top-level user session in the Antigravity desktop sidebar, similar to Claude Code Projects or OpenAI Codex threads.

## When to use

Use this skill when:
- A task is long-running or requires a clean, dedicated conversation that the user can inspect in their sidebar.
- You want to offload independent research, build tests, or large refactors into a separate session.
- The spawned session needs to report its results back to this coordinator chat automatically upon completion.

## How it works

1. It invokes Antigravity's internal `agentapi new-conversation` (or Connect-RPC `StartCascade`) without parent lineage.
2. The runtime creates the session with `nesting_depth = 0` and an empty `parent_conversation_id`, causing the desktop app to display it directly in the user's left sidebar.
3. The script automatically injects this conversation's ID (`$env:ANTIGRAVITY_CONVERSATION_ID`) into the spawned session's startup instructions.
4. When the spawned session completes its task, it calls `send_message` targeting this chat.
5. The incoming response is delivered into this context as a system notification without manual file reading or polling.

## Execution

### PowerShell (Windows)
```powershell
powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\.gemini\config\skills\spawn-session\scripts\spawn.ps1" -Title "Task Name" -Model "flash" -Prompt "Your instructions"
```

### Python (Cross-platform)
```bash
python "%USERPROFILE%/.gemini/config/skills/spawn-session/scripts/spawn.py" "Your instructions" --title "Task Name" --model flash
```

## Receiving responses

Do not poll or monitor files. When the spawned session finishes its work, the Antigravity messaging system automatically wakes this conversation and delivers the reply.
