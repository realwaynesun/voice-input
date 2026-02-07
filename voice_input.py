#!/usr/bin/env python3
"""
Voice Input Tool - Press and hold Right Option to record, release to transcribe.
Supports Chinese/English mixed speech using local Whisper or OpenAI API.
"""

import io
import os
import sys
import tempfile
import threading
from pathlib import Path

import numpy as np
import pyperclip
import sounddevice as sd
from pynput import keyboard
from scipy.io.wavfile import write as write_wav


# Configuration
SAMPLE_RATE = 16000  # Whisper requires 16kHz
HOTKEY = keyboard.Key.alt_r  # Right Option key
DEVICE_NAME = "Wireless Mic Rx"  # DJI Mic Mini; falls back to default if not found

# Backend: "api" (OpenAI API) or "local" (faster-whisper)
BACKEND = "local"

# Local model settings (only used when BACKEND = "local")
LOCAL_MODEL_SIZE = "small"  # Options: tiny, base, small, medium, large-v3

# API settings (only used when BACKEND = "api")
# Set OPENAI_API_KEY environment variable or edit here
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")

MULTILINGUAL_PROMPT = "这个project要refactor，この部分はまだ完成していない。请用TypeScript来implement。"


def find_device(name):
    """Find audio input device by name. Returns device index or None."""
    devices = sd.query_devices()
    for i, d in enumerate(devices):
        if name.lower() in d["name"].lower() and d["max_input_channels"] > 0:
            return i
    return None


class VoiceInput:
    def __init__(self, backend="api"):
        self.recording = False
        self.audio_data = []
        self.model = None
        self.stream = None
        self.backend = backend
        self.openai_client = None
        self.device_id = find_device(DEVICE_NAME)

    def load_model(self):
        """Load the transcription backend."""
        if self.backend == "api":
            self._init_api()
        else:
            self._init_local()

    def _init_api(self):
        """Initialize OpenAI API client."""
        try:
            from openai import OpenAI
        except ImportError:
            print("Installing openai package...")
            os.system(f"{sys.executable} -m pip install openai -q")
            from openai import OpenAI

        if not OPENAI_API_KEY:
            print("❌ Error: OPENAI_API_KEY not set!")
            print("Please set it via: export OPENAI_API_KEY='your-key'")
            sys.exit(1)

        self.openai_client = OpenAI(api_key=OPENAI_API_KEY)
        print("✅ OpenAI API ready")

    def _init_local(self):
        """Initialize local Whisper model."""
        from faster_whisper import WhisperModel

        print(f"Loading local Whisper model '{LOCAL_MODEL_SIZE}'...")
        print("(First run will download the model, please wait)")

        self.model = WhisperModel(
            LOCAL_MODEL_SIZE,
            device="cpu",
            compute_type="int8"
        )
        print("✅ Local model loaded")

    def audio_callback(self, indata, frames, time, status):
        """Callback for audio stream."""
        if status:
            print(f"Audio status: {status}", file=sys.stderr)
        if self.recording:
            self.audio_data.append(indata.copy())

    def start_recording(self):
        """Start recording audio."""
        if self.recording:
            return

        self.recording = True
        self.audio_data = []

        self.stream = sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=1,
            dtype=np.float32,
            device=self.device_id,
            callback=self.audio_callback
        )
        self.stream.start()
        print("\r🎤 Recording... (release key to stop)", end="", flush=True)

    def stop_recording(self):
        """Stop recording and transcribe."""
        if not self.recording:
            return

        self.recording = False

        if self.stream:
            self.stream.stop()
            self.stream.close()
            self.stream = None

        if not self.audio_data:
            print("\r❌ No audio recorded", end="\n")
            return

        print("\r⏳ Transcribing...", end="", flush=True)

        audio = np.concatenate(self.audio_data, axis=0).flatten()

        if len(audio) < SAMPLE_RATE * 0.3:
            print("\r❌ Recording too short", end="\n")
            return

        try:
            if self.backend == "api":
                text = self._transcribe_api(audio)
            else:
                text = self._transcribe_local(audio)

            if text:
                pyperclip.copy(text)
                print(f"\r✅ Copied: {text}", end="\n")
                os.system('afplay /System/Library/Sounds/Pop.aiff &')
            else:
                print("\r❌ No speech detected", end="\n")

        except Exception as e:
            print(f"\r❌ Transcription error: {e}", end="\n")

    def _transcribe_api(self, audio):
        """Transcribe using OpenAI API."""
        # Convert float32 audio to int16 WAV
        audio_int16 = (audio * 32767).astype(np.int16)

        # Write to in-memory buffer
        buffer = io.BytesIO()
        write_wav(buffer, SAMPLE_RATE, audio_int16)
        buffer.seek(0)
        buffer.name = "audio.wav"

        # Call OpenAI API
        response = self.openai_client.audio.transcriptions.create(
            model="whisper-1",
            file=buffer,
            response_format="text",
            prompt=MULTILINGUAL_PROMPT,
        )

        return response.strip()

    def _transcribe_local(self, audio):
        """Transcribe using local Whisper model."""
        segments, info = self.model.transcribe(
            audio,
            language=None,
            beam_size=5,
            vad_filter=True,
            initial_prompt=MULTILINGUAL_PROMPT,
        )
        return "".join(segment.text for segment in segments).strip()

    def on_press(self, key):
        """Handle key press."""
        if key == HOTKEY:
            self.start_recording()

    def on_release(self, key):
        """Handle key release."""
        if key == HOTKEY:
            threading.Thread(target=self.stop_recording, daemon=True).start()
        elif key == keyboard.Key.esc:
            print("\nExiting...")
            return False

    def run(self):
        """Main loop."""
        self.load_model()

        backend_name = "OpenAI API" if self.backend == "api" else f"Local ({LOCAL_MODEL_SIZE})"

        print("\n" + "=" * 50)
        print("🎙️  Voice Input Ready")
        print("=" * 50)
        device_info = sd.query_devices(self.device_id)["name"] if self.device_id is not None else "System Default"
        print(f"  • Mic: {device_info}")
        print(f"  • Backend: {backend_name}")
        print(f"  • Hold [{self._key_name()}] to record")
        print("  • Release to transcribe and copy to clipboard")
        print("  • Press [ESC] to exit")
        print("=" * 50 + "\n")

        with keyboard.Listener(
            on_press=self.on_press,
            on_release=self.on_release
        ) as listener:
            listener.join()

    def _key_name(self):
        """Get human-readable key name."""
        if HOTKEY == keyboard.Key.alt_r:
            return "Right Option"
        elif HOTKEY == keyboard.Key.alt_l:
            return "Left Option"
        elif HOTKEY == keyboard.Key.ctrl_r:
            return "Right Control"
        else:
            return str(HOTKEY)


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Voice Input Tool")
    parser.add_argument(
        "--local", "-l",
        action="store_true",
        help="Use local Whisper model"
    )
    parser.add_argument(
        "--api", "-a",
        action="store_true",
        help="Use OpenAI API (faster but costs money)"
    )
    args = parser.parse_args()

    if args.api:
        backend = "api"
    elif args.local:
        backend = "local"
    else:
        backend = BACKEND

    print("Note: macOS may request microphone access permission.")
    print("Please allow it in System Settings > Privacy & Security > Microphone\n")

    voice_input = VoiceInput(backend=backend)
    try:
        voice_input.run()
    except KeyboardInterrupt:
        print("\nExiting...")


if __name__ == "__main__":
    main()
