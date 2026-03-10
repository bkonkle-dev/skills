#!/usr/bin/env python3
"""Fetch a YouTube transcript without modifying the global Python environment."""

from __future__ import annotations

import argparse
import importlib.util
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import parse_qs, urlparse


BOOTSTRAP_ENV = "FIRECRAWL_API_YT_TRANSCRIPT_BOOTSTRAPPED"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fetch a YouTube transcript using a temporary virtualenv if needed.",
    )
    parser.add_argument("video", help="YouTube watch URL, youtu.be URL, or video ID")
    parser.add_argument(
        "--language",
        action="append",
        dest="languages",
        help="Preferred language code. Repeat to add fallback languages.",
    )
    parser.add_argument(
        "--no-timestamps",
        action="store_true",
        help="Print transcript text without timestamps.",
    )
    return parser.parse_args()


def extract_video_id(value: str) -> str:
    value = value.strip()
    if not value:
        raise ValueError("missing YouTube URL or video ID")

    parsed = urlparse(value)
    if not parsed.scheme and not parsed.netloc:
        return value

    host = parsed.netloc.lower()
    if host.endswith("youtu.be"):
        video_id = parsed.path.strip("/")
        if video_id:
            return video_id
    if "youtube.com" in host:
        if parsed.path == "/watch":
            video_id = parse_qs(parsed.query).get("v", [""])[0]
            if video_id:
                return video_id
        parts = [part for part in parsed.path.split("/") if part]
        if len(parts) >= 2 and parts[0] in {"shorts", "embed", "live"}:
            return parts[1]

    raise ValueError(f"could not extract a YouTube video ID from {value!r}")


def ensure_dependency() -> None:
    if importlib.util.find_spec("youtube_transcript_api") is not None:
        return

    if os.environ.get(BOOTSTRAP_ENV) == "1":
        raise RuntimeError(
            "youtube-transcript-api is unavailable even after bootstrapping; "
            "the sandbox may block package installation or network access",
        )

    with tempfile.TemporaryDirectory(prefix="yt-transcript-") as tmp:
        venv_dir = Path(tmp) / "venv"
        subprocess.run([sys.executable, "-m", "venv", str(venv_dir)], check=True)
        python_bin = venv_dir / "bin" / "python"
        subprocess.run(
            [str(python_bin), "-m", "pip", "install", "--quiet", "youtube-transcript-api"],
            check=True,
        )
        env = os.environ.copy()
        env[BOOTSTRAP_ENV] = "1"
        result = subprocess.run([str(python_bin), __file__, *sys.argv[1:]], env=env)
        raise SystemExit(result.returncode)


def fetch_transcript(video_id: str, languages: list[str], include_timestamps: bool) -> int:
    from youtube_transcript_api import YouTubeTranscriptApi  # type: ignore

    api = YouTubeTranscriptApi()
    fetched = api.fetch(video_id, languages=languages)
    for entry in fetched:
        if include_timestamps:
            print(f"[{entry.start:07.2f}] {entry.text}")
        else:
            print(entry.text)
    return 0


def main() -> int:
    args = parse_args()
    languages = args.languages or ["en"]

    try:
        video_id = extract_video_id(args.video)
        ensure_dependency()
        return fetch_transcript(video_id, languages, not args.no_timestamps)
    except subprocess.CalledProcessError as err:
        print(f"bootstrap failed: {err}", file=sys.stderr)
        return 1
    except Exception as err:
        print(f"transcript fetch failed: {err}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
