param(
    [string]$Title = "New Task Session",
    [string]$Model = "flash",
    [Parameter(Mandatory=$true)][string]$Prompt,
    [string]$ReplyTo = $env:ANTIGRAVITY_CONVERSATION_ID
)

# Resolve language_server executable from environment or standard locations
$agentExe = $env:ANTIGRAVITY_AGENTAPI_EXE

if (-not $agentExe -or -not (Test-Path $agentExe)) {
    # Check default Antigravity installation paths on Windows
    $localAppPath = Join-Path $env:LOCALAPPDATA "Programs\antigravity\resources\bin\language_server.exe"
    if (Test-Path $localAppPath) {
        $agentExe = $localAppPath
    } else {
        $found = Get-Command language_server.exe -ErrorAction SilentlyContinue
        if ($found) {
            $agentExe = $found.Source
        }
    }
}

if (-not $agentExe -or -not (Test-Path $agentExe)) {
    Write-Error "Could not find Antigravity language_server.exe. Ensure ANTIGRAVITY_AGENTAPI_EXE is set."
    exit 1
}

# Attach return conversation metadata so the spawned session knows who to message
if ($ReplyTo) {
    $fullPrompt = "$Prompt`n`n[System Instruction: You were spawned from parent conversation $ReplyTo. When you complete your work or have a result to report, send your message back to $ReplyTo using your send_message tool or by running: agentapi send-message $ReplyTo 'your message']"
} else {
    $fullPrompt = $Prompt
}

# Execute agentapi command to create top-level conversation
$result = & "$agentExe" agentapi new-conversation --title="$Title" --model="$Model" "$fullPrompt"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to spawn new conversation."
    exit $LASTEXITCODE
}

Write-Output $result
