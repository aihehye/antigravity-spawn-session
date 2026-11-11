param(
    [string]$Title = "New Task Session",
    [string]$Model = "flash",
    [Parameter(Mandatory=$true)][string]$Prompt,
    [string]$ReplyTo = $env:ANTIGRAVITY_CONVERSATION_ID
)

# Attach return conversation metadata so the spawned session knows who to message
if ($ReplyTo) {
    $fullPrompt = "$Prompt`n`n[System Instruction: You were spawned from parent conversation $ReplyTo. When you complete your work or have a result to report, send your message back to $ReplyTo using your send_message tool or by running: agentapi send-message $ReplyTo 'your message']"
} else {
    $fullPrompt = $Prompt
}

# 1. Resolve language_server executable from environment or dynamic system discovery
$agentExe = $env:ANTIGRAVITY_AGENTAPI_EXE

# Check active running language_server process
if (-not $agentExe -or -not (Test-Path $agentExe)) {
    $procPath = (Get-Process language_server -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path -First 1)
    if ($procPath -and (Test-Path $procPath)) {
        $agentExe = $procPath
    }
}

# Check default Windows user installation path
if (-not $agentExe -or -not (Test-Path $agentExe)) {
    $localAppPath = Join-Path $env:LOCALAPPDATA "Programs\antigravity\resources\bin\language_server.exe"
    if (Test-Path $localAppPath) {
        $agentExe = $localAppPath
    }
}

# Check Program Files system-wide installations
if (-not $agentExe -or -not (Test-Path $agentExe)) {
    $progFilesPath = "C:\Program Files\Antigravity\resources\bin\language_server.exe"
    if (Test-Path $progFilesPath) {
        $agentExe = $progFilesPath
    }
}

# Check PATH
if (-not $agentExe -or -not (Test-Path $agentExe)) {
    $found = Get-Command language_server.exe -ErrorAction SilentlyContinue
    if ($found) {
        $agentExe = $found.Source
    }
}

# 2. Try CLI execution if binary was found
if ($agentExe -and (Test-Path $agentExe)) {
    $result = & "$agentExe" agentapi new-conversation --title="$Title" --model="$Model" "$fullPrompt"
    if ($LASTEXITCODE -eq 0 -and $result) {
        Write-Output $result
        exit 0
    }
    Write-Warning "agentapi CLI failed (exit code $LASTEXITCODE). Attempting Connect-RPC fallback..."
}

# 3. Connect-RPC fallback via LanguageServerService/StartCascade
$lsAddress = $env:ANTIGRAVITY_LS_ADDRESS
$csrfToken = $env:ANTIGRAVITY_CSRF_TOKEN

if ($lsAddress -and $csrfToken) {
    $url = "http://$lsAddress/exa.language_server_pb.LanguageServerService/StartCascade"
    $body = @{
        initialPrompt = $fullPrompt
        workspaceUris = @()
    } | ConvertTo-Json -Compress

    $headers = @{
        "Content-Type" = "application/json"
        "x-codeium-csrf-token" = $csrfToken
    }

    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -TimeoutSec 10
        if ($response -and $response.cascadeId) {
            $output = [PSCustomObject]@{
                response = [PSCustomObject]@{
                    newConversation = [PSCustomObject]@{
                        conversationId = $response.cascadeId
                        title = $Title
                    }
                }
            }
            Write-Output ($output | ConvertTo-Json -Depth 5)
            exit 0
        }
    } catch {
        Write-Error "Connect-RPC fallback failed: $_"
    }
}

Write-Error "Could not spawn conversation. Neither language_server binary nor active RPC port could be reached."
exit 1
