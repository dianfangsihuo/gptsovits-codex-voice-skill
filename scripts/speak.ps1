param(
    [string]$Text,
    [string]$TextFile,
    [string]$OutputPath,
    [string]$OutputDir = "C:\Users\Administrator\Downloads\codex-gptsovits-voice",
    [string]$StatePath = "C:\Users\Administrator\.codex\skills\gptsovits-codex-voice\state.json",
    [string]$ApiUrl = "http://127.0.0.1:9880/tts",
    [string]$ReferenceAudio = "C:\Users\Administrator\Downloads\.lian\qu1\vocal_这本书的国际标准书号是九七八七零二零零二四七五九，全书一共分为三十二个章节。.wav.reformatted.wav_10.wav",
    [string]$PromptText = "这本书的国际标准书号是九七八七零二零零二四七五九，全书一共分为三十二个章节。",
    [ValidateSet("zh", "en", "ja", "ko", "yue", "all_zh", "all_ja", "all_yue", "all_ko", "auto", "auto_yue")]
    [string]$TextLang = "zh",
    [ValidateSet("zh", "en", "ja", "ko", "yue", "all_zh", "all_ja", "all_yue", "all_ko", "auto", "auto_yue")]
    [string]$PromptLang = "zh",
    [ValidateSet("cut0", "cut1", "cut2", "cut3", "cut4", "cut5")]
    [string]$TextSplitMethod = "cut5",
    [double]$SpeedFactor = 1.0,
    [int]$BatchSize = 1,
    [int]$TopK = 5,
    [double]$TopP = 1.0,
    [double]$Temperature = 1.0,
    [int]$Seed = -1,
    [switch]$NoPlay
)

$ErrorActionPreference = "Stop"

if ($TextFile) {
    if (-not (Test-Path -LiteralPath $TextFile)) {
        throw "Text file not found: $TextFile"
    }
    $Text = Get-Content -LiteralPath $TextFile -Raw -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($Text)) {
    throw "Provide text with -Text or a UTF-8 file with -TextFile."
}

if (-not (Test-Path -LiteralPath $ReferenceAudio)) {
    throw "Reference audio not found: $ReferenceAudio"
}

if (-not $OutputPath) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputPath = Join-Path $OutputDir "codex-voice-$timestamp.wav"
} else {
    $parent = Split-Path -Parent $OutputPath
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
}

$payload = [ordered]@{
    text = $Text
    text_lang = $TextLang
    ref_audio_path = $ReferenceAudio
    prompt_text = $PromptText
    prompt_lang = $PromptLang
    top_k = $TopK
    top_p = $TopP
    temperature = $Temperature
    text_split_method = $TextSplitMethod
    batch_size = $BatchSize
    speed_factor = $SpeedFactor
    streaming_mode = $false
    media_type = "wav"
    seed = $Seed
    parallel_infer = $true
    repetition_penalty = 1.35
}

$json = $payload | ConvertTo-Json -Depth 8
$body = [System.Text.Encoding]::UTF8.GetBytes($json)
$tempPath = "$OutputPath.tmp"

try {
    Invoke-WebRequest `
        -Uri $ApiUrl `
        -Method Post `
        -ContentType "application/json; charset=utf-8" `
        -Body $body `
        -OutFile $tempPath `
        -TimeoutSec 300 | Out-Null

    $bytes = [System.IO.File]::ReadAllBytes($tempPath)
    if ($bytes.Length -lt 12) {
        $preview = [System.Text.Encoding]::UTF8.GetString($bytes)
        throw "GPT-SoVITS returned an empty or invalid response. $preview"
    }

    $header = [System.Text.Encoding]::ASCII.GetString($bytes, 0, [Math]::Min(12, $bytes.Length))
    if (-not $header.StartsWith("RIFF")) {
        $previewLength = [Math]::Min(800, $bytes.Length)
        $preview = [System.Text.Encoding]::UTF8.GetString($bytes, 0, $previewLength)
        throw "GPT-SoVITS did not return wav audio. Response preview: $preview"
    }

    Move-Item -LiteralPath $tempPath -Destination $OutputPath -Force

    $summaryPath = [System.IO.Path]::ChangeExtension($OutputPath, ".json")
    $summary = [ordered]@{
        output_path = $OutputPath
        api_url = $ApiUrl
        reference_audio = $ReferenceAudio
        prompt_text = $PromptText
        text_lang = $TextLang
        prompt_lang = $PromptLang
        text_split_method = $TextSplitMethod
        speed_factor = $SpeedFactor
        created_at = (Get-Date).ToString("o")
        text = $Text
    }
    $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

    if (Test-Path -LiteralPath $StatePath) {
        try {
            $state = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            $state = [pscustomobject]@{}
        }
        $state | Add-Member -NotePropertyName "last_output_path" -NotePropertyValue $OutputPath -Force
        $state | Add-Member -NotePropertyName "last_spoken_at" -NotePropertyValue (Get-Date).ToString("o") -Force
        $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    }

    if (-not $NoPlay) {
        $player = New-Object System.Media.SoundPlayer
        $player.SoundLocation = $OutputPath
        $player.Load()
        $player.PlaySync()
    }

    [pscustomobject]@{
        output_path = $OutputPath
        summary_path = $summaryPath
        bytes = (Get-Item -LiteralPath $OutputPath).Length
    } | ConvertTo-Json -Depth 4
}
finally {
    if (Test-Path -LiteralPath $tempPath) {
        Remove-Item -LiteralPath $tempPath -Force
    }
}




