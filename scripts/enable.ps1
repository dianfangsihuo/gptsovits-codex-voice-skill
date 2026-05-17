param(
    [string]$StatePath = "C:\Users\Administrator\.codex\skills\gptsovits-codex-voice\state.json",
    [string]$OutputDir = "C:\Users\Administrator\Downloads\codex-gptsovits-voice",
    [string]$SessionPath,
    [switch]$SkipWarmup
)

$ErrorActionPreference = "Stop"

$parent = Split-Path -Parent $StatePath
if ($parent) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$watchScript = Join-Path $scriptDir "watch-session.ps1"
$speakScript = Join-Path $scriptDir "speak.ps1"
$argList = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$watchScript`"",
    "-StatePath", "`"$StatePath`""
)
if ($SessionPath) {
    $argList += @("-SessionPath", "`"$SessionPath`"")
}

$proc = Start-Process -FilePath "powershell.exe" -ArgumentList $argList -WindowStyle Hidden -PassThru
$watcherPid = $proc.Id

$state = [ordered]@{
    active = $true
    enabled_at = (Get-Date).ToString("o")
    output_dir = $OutputDir
    session_path = $SessionPath
    watcher_pid = $watcherPid
    mode = $(if ($SessionPath) { "session_watcher" } else { "all_sessions_watcher" })
    warmed_up = $false
}

$state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $StatePath -Encoding UTF8

if (-not $SkipWarmup) {
    try {
        $warmupPath = Join-Path $OutputDir "codex-voice-warmup.wav"
        $warmupText = -join @([char]0x9884, [char]0x70ED)
        & $speakScript -Text $warmupText -OutputPath $warmupPath -NoPlay | Out-Null
        $state.warmed_up = $true
        $state.warmed_up_at = (Get-Date).ToString("o")
        $state.warmup_output_path = $warmupPath
        $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    }
    catch {
        $state.warmup_error = $_.Exception.Message
        $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    }
}

$state | ConvertTo-Json -Depth 6
