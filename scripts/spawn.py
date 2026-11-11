#!/usr/bin/env python3
"""
Cross-platform helper to spawn an independent, top-level Antigravity conversation session.
Works on Windows, macOS, and Linux.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import urllib.request


def find_agentapi_exe():
    # 1. Environment variable injected by Antigravity
    exe = os.environ.get("ANTIGRAVITY_AGENTAPI_EXE")
    if exe and os.path.exists(exe):
        return exe

    # 2. Check running language_server process
    if sys.platform == "win32":
        try:
            cmd = ["powershell", "-NoProfile", "-Command", "(Get-Process language_server -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path -First 1)"]
            proc_out = subprocess.check_output(cmd, text=True, timeout=3).strip()
            if proc_out and os.path.exists(proc_out):
                return proc_out
        except Exception:
            pass

    # 3. Standard installation paths
    if sys.platform == "win32":
        candidates = [
            os.path.expandvars(r"%LOCALAPPDATA%\Programs\antigravity\resources\bin\language_server.exe"),
            r"C:\Program Files\Antigravity\resources\bin\language_server.exe",
            r"C:\Program Files (x86)\Antigravity\resources\bin\language_server.exe"
        ]
        for c in candidates:
            if os.path.exists(c):
                return c
    elif sys.platform == "darwin":
        candidates = [
            "/Applications/Antigravity.app/Contents/Resources/bin/language_server",
            os.path.expanduser("~/Applications/Antigravity.app/Contents/Resources/bin/language_server")
        ]
        for c in candidates:
            if os.path.exists(c):
                return c
    elif sys.platform.startswith("linux"):
        candidates = [
            os.path.expanduser("~/.local/share/antigravity/bin/language_server"),
            "/opt/antigravity/bin/language_server",
            "/usr/share/antigravity/bin/language_server"
        ]
        for c in candidates:
            if os.path.exists(c):
                return c

    # 4. PATH lookup
    which_exe = shutil.which("language_server.exe" if sys.platform == "win32" else "language_server")
    if which_exe:
        return which_exe

    return None


def spawn_via_rpc(title, model, full_prompt):
    ls_address = os.environ.get("ANTIGRAVITY_LS_ADDRESS")
    csrf_token = os.environ.get("ANTIGRAVITY_CSRF_TOKEN")
    if not ls_address or not csrf_token:
        return None

    url = f"http://{ls_address}/exa.language_server_pb.LanguageServerService/StartCascade"
    payload = {
        "initialPrompt": full_prompt,
        "workspaceUris": []
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "x-codeium-csrf-token": csrf_token
        }
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return json.dumps({"response": {"newConversation": {"conversationId": data.get("cascadeId"), "title": title}}}, indent=2)
    except Exception as e:
        sys.stderr.write(f"Connect-RPC fallback call failed: {e}\n")
        return None


def main():
    parser = argparse.ArgumentParser(description="Spawn a top-level Antigravity user session.")
    parser.add_argument("prompt", help="Initial prompt for the new session")
    parser.add_argument("--title", default="New Task Session", help="Session title in the sidebar")
    parser.add_argument("--model", default="flash", help="Model name: flash, pro, flash_lite")
    parser.add_argument("--reply-to", default=os.environ.get("ANTIGRAVITY_CONVERSATION_ID", ""), help="Parent conversation ID to receive replies")

    args = parser.parse_args()

    full_prompt = args.prompt
    if args.reply_to:
        full_prompt = (
            f"{args.prompt}\n\n"
            f"[System Instruction: You were spawned from parent conversation {args.reply_to}. "
            f"When you finish your task, send your report back to {args.reply_to} using your send_message tool "
            f"or by running: agentapi send-message {args.reply_to} 'your message']"
        )

    exe = find_agentapi_exe()
    if exe:
        cmd = [exe, "agentapi", "new-conversation", f"--title={args.title}", f"--model={args.model}", full_prompt]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode == 0:
            print(proc.stdout.strip())
            return 0
        else:
            sys.stderr.write(f"agentapi execution failed: {proc.stderr}\nFalling back to Connect-RPC...\n")

    rpc_res = spawn_via_rpc(args.title, args.model, full_prompt)
    if rpc_res:
        print(rpc_res)
        return 0

    sys.stderr.write("Error: Could not spawn conversation via agentapi or Connect-RPC.\n")
    return 1


if __name__ == "__main__":
    sys.exit(main())
