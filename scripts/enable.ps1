param(
    [string]$StatePath = "C:\Users\Administrator\.codex\skills\gptsovits-codex-voice\state.json",
    [string]$OutputDir = "C:\Users\Administrator\Downloads\codex-gptsovits-voice",
    [string]$SessionPath
)

$ErrorActionPreference = "Stop"

$parent = Split-Path -Parent $StatePath
if ($parent) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

if (-not $SessionPath) {
    $sessionRoot = Join-Path $env:USERPROFILE ".codex\sessions"
    $latest = Get-ChildItem -LiteralPath $sessionRoot -Recurse -Filter "rollout-*.jsonl" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($latest) {
        $SessionPath = $latest.FullName
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$watchScript = Join-Path $scriptDir "watch-session.ps1"
$argList = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$watchScript`"",
    "-StatePath", "`"$StatePath`""
)
if ($SessionPath) {
    $argList += @("-SessionPath", "`"$SessionPath`"")
}

$watcherPid = $null
$proc = Start-Process -FilePath "powershell.exe" -ArgumentList $argList -WindowStyle Hidden -PassThru
$watcherPid = $proc.Id

$state = [ordered]@{
    active = $true
    enabled_at = (Get-Date).ToString("o")
    output_dir = $OutputDir
    session_path = $SessionPath
    watcher_pid = $watcherPid
    mode = "session_watcher"
}

$state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $StatePath -Encoding UTF8
$state | ConvertTo-Json -Depth 6

