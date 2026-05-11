param(
    [string]$StatePath = "C:\Users\Administrator\.codex\skills\gptsovits-codex-voice\state.json"
)

$ErrorActionPreference = "Stop"

if (Test-Path -LiteralPath $StatePath) {
    try {
        $state = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($state.watcher_pid) {
            Stop-Process -Id ([int]$state.watcher_pid) -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
    }
    Remove-Item -LiteralPath $StatePath -Force
}

[ordered]@{
    active = $false
    disabled_at = (Get-Date).ToString("o")
} | ConvertTo-Json -Depth 4

