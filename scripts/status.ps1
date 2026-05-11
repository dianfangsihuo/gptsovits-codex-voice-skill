param(
    [string]$StatePath = "C:\Users\Administrator\.codex\skills\gptsovits-codex-voice\state.json"
)

$ErrorActionPreference = "Stop"

if (Test-Path -LiteralPath $StatePath) {
    Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8
} else {
    [ordered]@{
        active = $false
    } | ConvertTo-Json -Depth 4
}



