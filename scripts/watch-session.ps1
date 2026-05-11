param(
    [string]$SessionPath,
    [string]$StatePath = "C:\Users\Administrator\.codex\skills\gptsovits-codex-voice\state.json",
    [int]$PollIntervalMs = 500,
    [switch]$ReadExisting
)

$ErrorActionPreference = "Stop"

function Get-LatestSessionPath {
    $sessionRoot = Join-Path $env:USERPROFILE ".codex\sessions"
    $latest = Get-ChildItem -LiteralPath $sessionRoot -Recurse -Filter "rollout-*.jsonl" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $latest) {
        throw "No Codex session jsonl file found under $sessionRoot"
    }
    return $latest.FullName
}

function Read-NewText {
    param(
        [string]$Path,
        [long]$Position
    )

    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        if ($Position -gt $stream.Length) {
            $Position = 0
        }
        $stream.Seek($Position, [System.IO.SeekOrigin]::Begin) | Out-Null
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true, 4096, $true)
        try {
            $text = $reader.ReadToEnd()
            return [pscustomobject]@{
                Text = $text
                Position = $stream.Position
            }
        }
        finally {
            $reader.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Test-VoiceModeActive {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }
    try {
        $state = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        return [bool]$state.active
    }
    catch {
        return $false
    }
}

if (-not $SessionPath) {
    $SessionPath = Get-LatestSessionPath
}
if (-not (Test-Path -LiteralPath $SessionPath)) {
    throw "Session file not found: $SessionPath"
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$speakScript = Join-Path $scriptDir "speak.ps1"
$position = 0
if (-not $ReadExisting) {
    $position = (Get-Item -LiteralPath $SessionPath).Length
}
$seen = New-Object "System.Collections.Generic.HashSet[string]"

while (Test-VoiceModeActive -Path $StatePath) {
    $chunk = Read-NewText -Path $SessionPath -Position $position
    $position = $chunk.Position

    if (-not [string]::IsNullOrWhiteSpace($chunk.Text)) {
        foreach ($line in ($chunk.Text -split "`r?`n")) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            try {
                $entry = $line | ConvertFrom-Json
            }
            catch {
                continue
            }

            if ($entry.type -ne "event_msg" -or $entry.payload.type -ne "agent_message") {
                continue
            }

            $message = [string]$entry.payload.message
            $phase = [string]$entry.payload.phase
            if ([string]::IsNullOrWhiteSpace($message)) {
                continue
            }
            if ($phase -notin @("commentary", "final_answer")) {
                continue
            }

            $key = "$($entry.timestamp)|$phase|$message"
            if ($seen.Contains($key)) {
                continue
            }
            [void]$seen.Add($key)

            try {
                & $speakScript -Text $message | Out-Null
            }
            catch {
                $errorDir = Split-Path -Parent $StatePath
                $errorPath = Join-Path $errorDir "watcher-error.log"
                $stamp = Get-Date -Format "o"
                "[$stamp] $($_.Exception.Message)" | Add-Content -LiteralPath $errorPath -Encoding UTF8
            }
        }
    }

    Start-Sleep -Milliseconds $PollIntervalMs
}

