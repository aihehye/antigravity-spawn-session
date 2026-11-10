# spawn-session

An Antigravity skill that enables agents to programmatically spawn real, top-level user conversation sessions in the desktop sidebar, with automatic bidirectional messaging back to the coordinator chat.

## Overview

Unlike standard subagents that run hidden in background processes, `spawn-session` creates independent root conversations:

- **Visible in the left sidebar**: Created with `nesting_depth = 0` and an empty `parent_conversation_id`, making each spawned thread appear directly in the user's sidebar.
- **Bi-directional communication**: The spawned session automatically receives the coordinator's ID and can send reports back using `send_message`.
- **Zero file polling**: The coordinator receives replies through Antigravity's reactive message delivery without reading foreign transcript files.
- **Cross-platform**: Includes both PowerShell (`spawn.ps1`) for Windows and Python (`spawn.py`) for macOS, Linux, and Windows.

---

## Installation

### Option 1: Global installation (Available in all projects)

Clone or copy this repository into your global Antigravity skills directory:

**Windows (PowerShell):**
```powershell
git clone https://github.com/<your-username>/antigravity-spawn-session.git "$env:USERPROFILE\.gemini\config\skills\spawn-session"
```

**macOS / Linux:**
```bash
git clone https://github.com/<your-username>/antigravity-spawn-session.git ~/.gemini/config/skills/spawn-session
```

### Option 2: Project-level installation

Clone into your repository's local skill folder:

```bash
git clone https://github.com/<your-username>/antigravity-spawn-session.git .agents/skills/spawn-session
```

---

## Usage

### In chat
Ask the agent in natural language:
> "Spawn a new sidebar session named 'Benchmark Suite' to run performance tests and report back."

### Manual CLI invocation

**PowerShell:**
```powershell
powershell -ExecutionPolicy Bypass -File "scripts/spawn.ps1" -Title "Data Migration" -Model "flash" -Prompt "Analyze schema changes and verify indexes."
```

**Python:**
```bash
python scripts/spawn.py "Analyze schema changes and verify indexes." --title "Data Migration" --model "flash"
```

---

## How it works

1. The script resolves the active Antigravity Language Server via `$env:ANTIGRAVITY_AGENTAPI_EXE` or `$env:ANTIGRAVITY_LS_ADDRESS`.
2. It invokes `agentapi new-conversation` (or Connect-RPC `StartCascade`) without parent lineage flags.
3. The server generates a unique UUID, writes the record to `conversation_summaries.db`, and pushes an update to the Electron UI.
4. The spawned agent executes its instructions, and upon completion, uses `send_message` targeting the parent conversation ID to notify the coordinator.

---

## License

MIT
