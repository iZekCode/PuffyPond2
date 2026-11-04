#!/usr/bin/env python3
"""Makes the audio files for the tracing guide's spoken lines (one short clip per line in units.txt).

The app plays PuffyPond/Voice/guide-<slug>.mp3 when it finds every line of a direction as a clip, and falls back
to the device's own (more robotic) voice otherwise. Drop in your own recordings under the same names to use them.

  python3 tools/voice/make_clips.py --backend edge            # free, needs `pip install edge-tts`
  AZURE_SPEECH_KEY=... AZURE_SPEECH_REGION=southeastasia \
  python3 tools/voice/make_clips.py --backend azure           # Azure AI Speech, official and licensed

Voices: id-ID-GadisNeural (female, default) or id-ID-ArdiNeural (male). Use --force to remake existing clips.
The edge backend uses the unofficial Microsoft Edge read-aloud service: fine to try, but check its terms before
shipping the audio in a published app. The azure backend is the one to ship with.
"""
import argparse
import asyncio
import os
import re
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "PuffyPond" / "Voice"


def clip_name(line: str) -> str:
    """Must match GuideVoice.clipName(for:) in the app."""
    return "guide-" + re.sub(r"[^a-z0-9]+", "-", line.lower()).strip("-")


async def with_edge(lines, voice, rate, pitch, force):
    import edge_tts  # pip install edge-tts

    for line in lines:
        path = OUT / (clip_name(line) + ".mp3")
        if path.exists() and not force:
            continue
        await edge_tts.Communicate(line, voice, rate=rate, pitch=pitch).save(str(path))
        print("made", path.name)


def with_azure(lines, voice, rate, pitch, force):
    key = os.environ["AZURE_SPEECH_KEY"]
    region = os.environ.get("AZURE_SPEECH_REGION", "southeastasia")
    url = f"https://{region}.tts.speech.microsoft.com/cognitiveservices/v1"
    for line in lines:
        path = OUT / (clip_name(line) + ".mp3")
        if path.exists() and not force:
            continue
        ssml = (
            "<speak version='1.0' xml:lang='id-ID'>"
            f"<voice name='{voice}'><prosody rate='{rate}' pitch='{pitch}'>{line}</prosody></voice></speak>"
        )
        request = urllib.request.Request(
            url,
            data=ssml.encode("utf-8"),
            headers={
                "Ocp-Apim-Subscription-Key": key,
                "Content-Type": "application/ssml+xml",
                "X-Microsoft-OutputFormat": "audio-24khz-48kbitrate-mono-mp3",
                "User-Agent": "PuffyPondVoice",
            },
        )
        with urllib.request.urlopen(request) as response:
            path.write_bytes(response.read())
        print("made", path.name)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--backend", choices=["edge", "azure"], default="edge")
    parser.add_argument("--voice", default="id-ID-GadisNeural")
    parser.add_argument("--rate", default="+0%", help='speaking speed, e.g. "-5%%" (edge) or "-5%%" (azure)')
    parser.add_argument("--pitch", default=None, help='edge: "+8Hz"; azure: "+8%%"')
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    lines = [l.strip() for l in (HERE / "units.txt").read_text(encoding="utf-8").splitlines() if l.strip()]
    OUT.mkdir(parents=True, exist_ok=True)
    if args.backend == "edge":
        asyncio.run(with_edge(lines, args.voice, args.rate, args.pitch or "+0Hz", args.force))
    else:
        if "AZURE_SPEECH_KEY" not in os.environ:
            sys.exit("Set AZURE_SPEECH_KEY (and AZURE_SPEECH_REGION) first.")
        with_azure(lines, args.voice, args.rate, args.pitch or "+0%", args.force)
    print(f"{len(lines)} lines -> {OUT}")


if __name__ == "__main__":
    main()
