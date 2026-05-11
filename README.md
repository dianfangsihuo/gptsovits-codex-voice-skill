# GPT-SoVITS Codex Voice

Codex skill for speaking Codex replies through a local GPT-SoVITS API.

It supports two modes:

- one-shot synthesis: send text to GPT-SoVITS and play the generated WAV
- persistent voice mode: watch the current Codex session log and automatically speak new assistant messages

## Requirements

- Windows PowerShell
- Codex desktop skill directory support
- GPT-SoVITS API running at `http://127.0.0.1:9880/tts`
- A reference audio file available locally

Default reference audio:

```text
C:\Users\Administrator\Downloads\.lian\qu1\vocal_这本书的国际标准书号是九七八七零二零零二四七五九，全书一共分为三十二个章节。.wav.reformatted.wav_10.wav
```

Default prompt text:

```text
这本书的国际标准书号是九七八七零二零零二四七五九，全书一共分为三十二个章节。
```

## Install

Copy this folder to:

```text
C:\Users\Administrator\.codex\skills\gptsovits-codex-voice
```

Then restart or refresh Codex so it can discover the skill.

The skill name is:

```text
$gptsovits-codex-voice
```

## Usage

Speak a text once:

```powershell
C:\Users\Administrator\.codex\skills\gptsovits-codex-voice\scripts\speak.ps1 `
  -Text "你好，我是 Codex。这句话会被合成为语音并自动播放。"
```

Enable persistent voice mode:

```powershell
C:\Users\Administrator\.codex\skills\gptsovits-codex-voice\scripts\enable.ps1
```

Disable persistent voice mode:

```powershell
C:\Users\Administrator\.codex\skills\gptsovits-codex-voice\scripts\disable.ps1
```

Check status:

```powershell
C:\Users\Administrator\.codex\skills\gptsovits-codex-voice\scripts\status.ps1
```

When voice mode is active, `watch-session.ps1` runs in the background, tails the current Codex session `.jsonl`, and sends new assistant `commentary` or `final_answer` messages to GPT-SoVITS automatically. This avoids passing every reply through `-Text` manually.

## Playback

The generated WAV is played through .NET `System.Media.SoundPlayer`, not through the Windows default audio app. This avoids opening NetEase Cloud Music or other associated players.

Use `-NoPlay` to synthesize without playback:

```powershell
.\scripts\speak.ps1 -Text "只保存，不播放。" -NoPlay
```

## Files

- `SKILL.md`: Codex skill instructions
- `agents/openai.yaml`: Codex UI metadata
- `scripts/speak.ps1`: call GPT-SoVITS and play the generated WAV
- `scripts/enable.ps1`: enable persistent voice mode and start the watcher
- `scripts/disable.ps1`: disable voice mode and stop the watcher
- `scripts/status.ps1`: show current voice mode state
- `scripts/watch-session.ps1`: watch Codex session logs for assistant messages

Runtime files such as `state.json`, `watcher-error.log`, and generated audio are intentionally ignored by Git.
