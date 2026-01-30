# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Koe** (声) - macOS voice input tool with two modes:

1. **MCP Server** (`koe_mcp.py`) - Voice input for Claude Code via MCP protocol
2. **Standalone** (`voice_input.py`) - Hotkey-triggered voice input to clipboard

Supports Chinese/English/Japanese mixed speech recognition using local Whisper model or OpenAI API.

## MCP Server (for Claude Code)

```bash
# Add to Claude Code
claude mcp add koe -- /Users/waynesun/voice-input/venv/bin/python /Users/waynesun/voice-input/koe_mcp.py

# Restart Claude Code, then use:
# - voice_input: Records until you press ESC
```

**Usage:**
1. Ask Claude: "use voice input" or "record my voice"
2. Hear start sound, see "🎤 RECORDING..."
3. Speak naturally
4. Press **Right Option** key to stop recording
5. Transcription returned to Claude

Environment variables:
- `KOE_BACKEND`: "local" (default) or "api"
- `KOE_MODEL_SIZE`: "tiny", "base", "small" (default), "medium", "large-v3"
- `OPENAI_API_KEY`: Required if using api backend

## Standalone Mode (Hotkey)

```bash
# Run with local Whisper model (default)
./venv/bin/python voice_input.py

# Run with OpenAI API
OPENAI_API_KEY=your-key ./venv/bin/python voice_input.py --api

# Via start script
./start.sh
```

## System Dependencies

```bash
brew install portaudio ffmpeg
```

## Architecture

Two entry points sharing core audio/transcription logic:

**koe_mcp.py** (MCP Server):
- FastMCP server with `voice_input` and `voice_input_timed` tools
- Auto-silence detection (1.5s silence → stop)
- Returns transcribed text directly to Claude

**voice_input.py** (Standalone):
- VoiceInput class with hotkey listener (pynput)
- Press-and-hold Right Option to record
- Copies result to clipboard

**Shared components:**
- Audio recording via sounddevice (16kHz, mono)
- Transcription via faster-whisper (local) or OpenAI API
- System sounds for feedback (afplay)

## Configuration

**MCP** - via environment variables (see above)

**Standalone** - edit constants at top of `voice_input.py`:

```python
HOTKEY = keyboard.Key.alt_r   # Trigger key
BACKEND = "local"             # "local" or "api"
LOCAL_MODEL_SIZE = "small"    # tiny, base, small, medium, large-v3
```

## macOS Permissions Required

1. **Microphone**: System Settings > Privacy & Security > Microphone
2. **Accessibility**: System Settings > Privacy & Security > Accessibility (add Terminal/iTerm)

## LaunchAgent (Auto-start)

```bash
cp com.user.voice-input.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.voice-input.plist
```

Logs: `/tmp/voice-input.log`, `/tmp/voice-input.err`
