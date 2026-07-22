#!/usr/bin/env python3
import os
import sys
from openai import OpenAI

def transcribe_audio(file_path, api_key):
    client = OpenAI(api_key=api_key)
    with open(file_path, "rb") as audio_file:
        transcription = client.audio.transcriptions.create(
            model="whisper-1", 
            file=audio_file,
            response_format="text"
        )
    return transcription.strip()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: transcribe_audio.py <audio_file>")
        sys.exit(1)
        
    path = sys.argv[1]
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("Error: OPENAI_API_KEY environment variable not set.", file=sys.stderr)
        sys.exit(1)
        
    try:
        text = transcribe_audio(path, api_key)
        print(text)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
