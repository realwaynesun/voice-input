#!/usr/bin/env python3
"""
Koe (声) MCP Server - Voice input for Claude Code via MCP protocol.
Speak naturally, get transcribed text back.
"""

import io
import os
import sys
import time
import threading
import numpy as np
import sounddevice as sd
from scipy.io.wavfile import write as write_wav
from pynput import keyboard

# Configuration
SAMPLE_RATE = 16000
MAX_DURATION = 60  # Maximum recording duration in seconds
MIN_DURATION = 0.5  # Minimum recording duration
STOP_KEY = keyboard.Key.alt_r  # Right Option key to stop recording
DEVICE_NAME = os.environ.get("KOE_DEVICE", "Wireless Mic Rx")  # DJI Mic Mini

# Backend settings
BACKEND = os.environ.get("KOE_BACKEND", "local")  # "local" or "api"
LOCAL_MODEL_SIZE = os.environ.get("KOE_MODEL_SIZE", "small")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")

# Lazy-loaded model
_whisper_model = None
_openai_client = None


def get_whisper_model():
    """Lazy load local Whisper model."""
    global _whisper_model
    if _whisper_model is None:
        from faster_whisper import WhisperModel
        _whisper_model = WhisperModel(
            LOCAL_MODEL_SIZE,
            device="cpu",
            compute_type="int8"
        )
    return _whisper_model


def get_openai_client():
    """Lazy load OpenAI client."""
    global _openai_client
    if _openai_client is None:
        from openai import OpenAI
        if not OPENAI_API_KEY:
            raise ValueError("OPENAI_API_KEY not set")
        _openai_client = OpenAI(api_key=OPENAI_API_KEY)
    return _openai_client


def find_device(name):
    """Find audio input device by name. Returns device index or None."""
    devices = sd.query_devices()
    for i, d in enumerate(devices):
        if name.lower() in d["name"].lower() and d["max_input_channels"] > 0:
            return i
    return None


def record_until_keypress() -> np.ndarray:
    """
    Record audio until user presses ESC key.
    Returns numpy array of audio data.
    """
    audio_chunks = []
    recording = True
    stop_event = threading.Event()

    def audio_callback(indata, frames, time_info, status):
        if status:
            print(f"Audio status: {status}", file=sys.stderr)
        if recording:
            audio_chunks.append(indata.copy())

    def on_press(key):
        nonlocal recording
        if key == STOP_KEY:
            recording = False
            stop_event.set()
            return False  # Stop listener

    # Play start sound
    os.system('afplay /System/Library/Sounds/Blow.aiff &')
    print("\n" + "=" * 50, file=sys.stderr)
    print("🎤 RECORDING... Press [Right Option] to stop", file=sys.stderr)
    print("=" * 50, file=sys.stderr, flush=True)

    # Start keyboard listener in background
    listener = keyboard.Listener(on_press=on_press)
    listener.start()

    device_id = find_device(DEVICE_NAME)
    device_info = sd.query_devices(device_id)["name"] if device_id is not None else "System Default"
    print(f"🎙️  Mic: {device_info}", file=sys.stderr, flush=True)

    with sd.InputStream(
        samplerate=SAMPLE_RATE,
        channels=1,
        dtype=np.float32,
        device=device_id,
        callback=audio_callback
    ):
        start_time = time.time()
        while recording and (time.time() - start_time) < MAX_DURATION:
            time.sleep(0.1)

    listener.stop()

    # Play stop sound
    os.system('afplay /System/Library/Sounds/Pop.aiff &')
    print("✅ Recording stopped", file=sys.stderr, flush=True)

    if not audio_chunks:
        return np.array([])

    return np.concatenate(audio_chunks, axis=0).flatten()


MULTILINGUAL_PROMPT = "这个project要refactor，この部分はまだ完成していない。请用TypeScript来implement。"


def transcribe_local(audio: np.ndarray) -> str:
    """Transcribe using local Whisper model."""
    model = get_whisper_model()
    segments, _ = model.transcribe(
        audio,
        language=None,
        beam_size=5,
        vad_filter=True,
        initial_prompt=MULTILINGUAL_PROMPT,
    )
    return "".join(segment.text for segment in segments).strip()


def transcribe_api(audio: np.ndarray) -> str:
    """Transcribe using OpenAI API."""
    client = get_openai_client()

    # Convert to WAV
    audio_int16 = (audio * 32767).astype(np.int16)
    buffer = io.BytesIO()
    write_wav(buffer, SAMPLE_RATE, audio_int16)
    buffer.seek(0)
    buffer.name = "audio.wav"

    response = client.audio.transcriptions.create(
        model="whisper-1",
        file=buffer,
        response_format="text",
        prompt=MULTILINGUAL_PROMPT,
    )
    return response.strip()


def transcribe(audio: np.ndarray) -> str:
    """Transcribe audio using configured backend."""
    if len(audio) < SAMPLE_RATE * MIN_DURATION:
        return ""

    if BACKEND == "api":
        return transcribe_api(audio)
    else:
        return transcribe_local(audio)


# MCP Server Implementation
try:
    from mcp.server.fastmcp import FastMCP

    mcp = FastMCP("koe")

    @mcp.tool()
    def voice_input() -> str:
        """
        Record voice input and transcribe to text.

        🎤 Press [Right Option] key to stop recording when done speaking.

        Supports Chinese, English, Japanese and other languages.
        Uses local Whisper model (no API costs, runs offline).

        Returns the transcribed text.
        """
        audio = record_until_keypress()

        if len(audio) < SAMPLE_RATE * MIN_DURATION:
            return "[Recording too short]"

        print("⏳ Transcribing...", file=sys.stderr, flush=True)
        text = transcribe(audio)

        if not text:
            return "[No speech detected]"

        return text

except ImportError:
    mcp = None
    print("MCP not installed. Run: pip install mcp", file=sys.stderr)


def main():
    """Run MCP server."""
    if mcp is None:
        print("Error: MCP package not installed")
        print("Install with: pip install mcp")
        sys.exit(1)

    mcp.run()


if __name__ == "__main__":
    main()
