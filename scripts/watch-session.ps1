param(
    [string]$SessionPath,
    [string]$StatePath = "C:\Users\Administrator\.codex\skills\gptsovits-codex-voice\state.json",
    [int]$PollIntervalMs = 250,
    [switch]$ReadExisting
)

$ErrorActionPreference = "Stop"

function Get-SessionPaths {
    $sessionRoot = Join-Path $env:USERPROFILE ".codex\sessions"
    if (-not (Test-Path -LiteralPath $sessionRoot)) {
        return @()
    }
    return @(Get-ChildItem -LiteralPath $sessionRoot -Recurse -Filter "rollout-*.jsonl" | ForEach-Object { $_.FullName })
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

function Get-CompleteLines {
    param(
        [string]$Path,
        [string]$Text,
        [hashtable]$Pending
    )

    if ($Pending.ContainsKey($Path)) {
        $Text = [string]$Pending[$Path] + $Text
    }

    $endsWithNewline = $Text.EndsWith("`n") -or $Text.EndsWith("`r")
    $lines = @($Text -split "`r?`n")
    if (-not $endsWithNewline) {
        $Pending[$Path] = $lines[-1]
        if ($lines.Count -le 1) {
            return @()
        }
        return @($lines[0..($lines.Count - 2)])
    }

    $Pending[$Path] = ""
    return $lines
}

if ($SessionPath -and -not (Test-Path -LiteralPath $SessionPath)) {
    throw "Session file not found: $SessionPath"
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$speakScript = Join-Path $scriptDir "speak.ps1"
$positions = @{}
$pending = @{}

if ($SessionPath) {
    $positions[$SessionPath] = 0
    if (-not $ReadExisting) {
        $positions[$SessionPath] = (Get-Item -LiteralPath $SessionPath).Length
    }
}
else {
    foreach ($path in Get-SessionPaths) {
        $positions[$path] = 0
        if (-not $ReadExisting) {
            $positions[$path] = (Get-Item -LiteralPath $path).Length
        }
    }
}

$seen = New-Object "System.Collections.Generic.HashSet[string]"

while (Test-VoiceModeActive -Path $StatePath) {
    if ($SessionPath) {
        $paths = @($SessionPath)
    }
    else {
        $paths = Get-SessionPaths
        foreach ($path in $paths) {
            if (-not $positions.ContainsKey($path)) {
                $positions[$path] = 0
            }
        }
    }

    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }
        if (-not $positions.ContainsKey($path)) {
            $positions[$path] = 0
        }

        $chunk = Read-NewText -Path $path -Position ([long]$positions[$path])
        $positions[$path] = $chunk.Position
        if ([string]::IsNullOrEmpty($chunk.Text)) {
            continue
        }

        foreach ($line in (Get-CompleteLines -Path $path -Text ([string]$chunk.Text) -Pending $pending)) {
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

            $key = "$path|$($entry.timestamp)|$phase|$message"
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
