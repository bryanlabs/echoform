#!/usr/bin/env python3
"""Benchmark Echoform candidate transcription engines against one audio file."""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
import re
import statistics
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable


ProviderFn = Callable[["BenchConfig"], "BenchResult"]


@dataclass
class BenchConfig:
    audio: Path
    audio_seconds: float
    language: str
    parakeet_model: str


@dataclass
class BenchResult:
    provider: str
    status: str
    transcript: str = ""
    wall_seconds: float | None = None
    realtime_factor: float | None = None
    error: str = ""
    notes: str = ""
    runs: list[float] = field(default_factory=list)
    wer: float | None = None

    def as_json(self) -> dict:
        return {
            "provider": self.provider,
            "status": self.status,
            "wall_seconds": self.wall_seconds,
            "realtime_factor": self.realtime_factor,
            "runs": self.runs,
            "wer": self.wer,
            "notes": self.notes,
            "error": self.error,
            "transcript": self.transcript,
        }


def audio_duration(path: Path) -> float:
    output = subprocess.check_output(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=nk=1:nw=1",
            str(path),
        ],
        text=True,
    )
    return float(output.strip())


def normalize_words(text: str) -> list[str]:
    text = text.casefold()
    text = re.sub(r"[^\w\s]", " ", text, flags=re.UNICODE)
    return [word for word in text.split() if word]


def word_error_rate(reference: str, hypothesis: str) -> float:
    ref = normalize_words(reference)
    hyp = normalize_words(hypothesis)
    if not ref:
        return 0.0 if not hyp else 1.0

    prev = list(range(len(hyp) + 1))
    for i, ref_word in enumerate(ref, start=1):
        current = [i]
        for j, hyp_word in enumerate(hyp, start=1):
            substitution = prev[j - 1] + (ref_word != hyp_word)
            insertion = current[j - 1] + 1
            deletion = prev[j] + 1
            current.append(min(substitution, insertion, deletion))
        prev = current
    return prev[-1] / len(ref)


def time_call(func: Callable[[], str]) -> tuple[str, float]:
    start = time.perf_counter()
    transcript = func()
    return transcript, time.perf_counter() - start


def run_parakeet(config: BenchConfig) -> BenchResult:
    with tempfile.TemporaryDirectory(prefix="echoform-parakeet-") as temp_dir:
        output_dir = Path(temp_dir)
        argv = [
            "uvx",
            "--from",
            "parakeet-mlx",
            "parakeet-mlx",
            str(config.audio),
            "--model",
            config.parakeet_model,
            "--output-format",
            "txt",
            "--output-dir",
            str(output_dir),
            "--output-template",
            "{filename}",
        ]

        def invoke() -> str:
            completed = subprocess.run(argv, capture_output=True, text=True)
            if completed.returncode != 0:
                detail = (completed.stderr or completed.stdout).strip()
                raise RuntimeError(detail or f"parakeet exited {completed.returncode}")
            candidates = sorted(output_dir.glob("*.txt"))
            if not candidates:
                raise RuntimeError("parakeet completed but did not write a txt file")
            return candidates[-1].read_text(encoding="utf-8").strip()

        try:
            transcript, wall_seconds = time_call(invoke)
        except Exception as exc:  # noqa: BLE001 - surface provider errors in report.
            return BenchResult(
                provider="parakeet-mlx",
                status="error",
                error=str(exc),
                notes="Requires uv, ffmpeg, and the MLX Parakeet package.",
            )

    return BenchResult(
        provider="parakeet-mlx",
        status="ok",
        transcript=transcript,
        wall_seconds=wall_seconds,
        realtime_factor=config.audio_seconds / wall_seconds if wall_seconds else None,
        notes=f"Model: {config.parakeet_model}",
    )


def multipart_post(
    url: str,
    fields: list[tuple[str, str]],
    file_path: Path,
    auth_header: str,
) -> dict:
    boundary = f"----echoform-{uuid.uuid4().hex}"
    body = bytearray()

    for name, value in fields:
        body.extend(f"--{boundary}\r\n".encode())
        body.extend(f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode())
        body.extend(str(value).encode())
        body.extend(b"\r\n")

    content_type = mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"
    body.extend(f"--{boundary}\r\n".encode())
    body.extend(
        f'Content-Disposition: form-data; name="file"; filename="{file_path.name}"\r\n'.encode()
    )
    body.extend(f"Content-Type: {content_type}\r\n\r\n".encode())
    body.extend(file_path.read_bytes())
    body.extend(b"\r\n")
    body.extend(f"--{boundary}--\r\n".encode())

    request = urllib.request.Request(
        url,
        data=bytes(body),
        headers={
            "Authorization": auth_header,
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Accept": "application/json",
            "User-Agent": "EchoformBenchmark/0.1",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code}: {detail}") from exc


def run_xai_grok(config: BenchConfig) -> BenchResult:
    api_key = os.environ.get("XAI_API_KEY")
    if not api_key:
        return BenchResult(
            provider="xai-grok-stt",
            status="skipped",
            notes="Set XAI_API_KEY to benchmark xAI Grok speech-to-text.",
        )

    def invoke() -> str:
        result = multipart_post(
            "https://api.x.ai/v1/stt",
            [("format", "true"), ("language", config.language)],
            config.audio,
            f"Bearer {api_key}",
        )
        return str(result.get("text", "")).strip()

    try:
        transcript, wall_seconds = time_call(invoke)
    except Exception as exc:  # noqa: BLE001
        return BenchResult(provider="xai-grok-stt", status="error", error=str(exc))

    return BenchResult(
        provider="xai-grok-stt",
        status="ok",
        transcript=transcript,
        wall_seconds=wall_seconds,
        realtime_factor=config.audio_seconds / wall_seconds if wall_seconds else None,
        notes="Hosted xAI STT endpoint",
    )


def run_groq_transcribe(model: str) -> ProviderFn:
    def provider(config: BenchConfig) -> BenchResult:
        api_key = os.environ.get("GROQ_API_KEY")
        name = f"groq-{model}"
        if not api_key:
            return BenchResult(
                provider=name,
                status="skipped",
                notes="Set GROQ_API_KEY to benchmark Groq Whisper transcription.",
            )

        def invoke() -> str:
            result = multipart_post(
                "https://api.groq.com/openai/v1/audio/transcriptions",
                [
                    ("model", model),
                    ("language", config.language),
                    ("response_format", "json"),
                    ("temperature", "0"),
                ],
                config.audio,
                f"Bearer {api_key}",
            )
            return str(result.get("text", "")).strip()

        try:
            transcript, wall_seconds = time_call(invoke)
        except Exception as exc:  # noqa: BLE001
            return BenchResult(provider=name, status="error", error=str(exc))

        return BenchResult(
            provider=name,
            status="ok",
            transcript=transcript,
            wall_seconds=wall_seconds,
            realtime_factor=config.audio_seconds / wall_seconds if wall_seconds else None,
            notes="Hosted Groq audio transcription endpoint",
        )

    return provider


def run_groq_translate(config: BenchConfig) -> BenchResult:
    api_key = os.environ.get("GROQ_API_KEY")
    name = "groq-whisper-large-v3-translate"
    if not api_key:
        return BenchResult(
            provider=name,
            status="skipped",
            notes="Set GROQ_API_KEY to benchmark Groq Spanish-to-English translation.",
        )

    def invoke() -> str:
        result = multipart_post(
            "https://api.groq.com/openai/v1/audio/translations",
            [
                ("model", "whisper-large-v3"),
                ("language", "en"),
                ("response_format", "json"),
                ("temperature", "0"),
            ],
            config.audio,
            f"Bearer {api_key}",
        )
        return str(result.get("text", "")).strip()

    try:
        transcript, wall_seconds = time_call(invoke)
    except Exception as exc:  # noqa: BLE001
        return BenchResult(provider=name, status="error", error=str(exc))

    return BenchResult(
        provider=name,
        status="ok",
        transcript=transcript,
        wall_seconds=wall_seconds,
        realtime_factor=config.audio_seconds / wall_seconds if wall_seconds else None,
        notes="Uses Groq's audio translations endpoint, so compare against an English reference.",
    )


PROVIDERS: dict[str, ProviderFn] = {
    "parakeet": run_parakeet,
    "xai-grok": run_xai_grok,
    "groq-turbo": run_groq_transcribe("whisper-large-v3-turbo"),
    "groq-large": run_groq_transcribe("whisper-large-v3"),
    "groq-translate": run_groq_translate,
}


def aggregate_results(results: list[BenchResult]) -> BenchResult:
    first = results[0]
    if first.status != "ok" or len(results) == 1:
        return first

    ok_runs = [result for result in results if result.status == "ok" and result.wall_seconds]
    if not ok_runs:
        return first

    wall_runs = [result.wall_seconds for result in ok_runs if result.wall_seconds is not None]
    median_wall = statistics.median(wall_runs)
    best = min(ok_runs, key=lambda result: result.wall_seconds or float("inf"))
    return BenchResult(
        provider=first.provider,
        status="ok",
        transcript=best.transcript,
        wall_seconds=median_wall,
        realtime_factor=best.realtime_factor,
        notes=first.notes,
        runs=wall_runs,
    )


def format_seconds(value: float | None) -> str:
    return "" if value is None else f"{value:.2f}"


def format_factor(value: float | None) -> str:
    return "" if value is None else f"{value:.1f}x"


def format_wer(value: float | None) -> str:
    return "" if value is None else f"{value * 100:.1f}%"


def print_table(results: list[BenchResult]) -> None:
    print("| Provider | Status | Runs | Wall s | Real-time | WER | Notes |")
    print("| --- | --- | ---: | ---: | ---: | ---: | --- |")
    for result in results:
        runs = len(result.runs) if result.runs else (1 if result.wall_seconds else 0)
        notes = result.notes or result.error
        print(
            "| "
            + " | ".join(
                [
                    result.provider,
                    result.status,
                    str(runs),
                    format_seconds(result.wall_seconds),
                    format_factor(result.realtime_factor),
                    format_wer(result.wer),
                    notes.replace("|", "\\|"),
                ]
            )
            + " |"
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("audio", type=Path, help="Audio file to benchmark.")
    parser.add_argument(
        "--providers",
        default="parakeet,xai-grok,groq-turbo,groq-large,groq-translate",
        help=f"Comma-separated provider IDs. Available: {', '.join(PROVIDERS)}",
    )
    parser.add_argument("--language", default="es", help="Input language code.")
    parser.add_argument(
        "--parakeet-model",
        default="mlx-community/parakeet-tdt-0.6b-v3",
        help="Parakeet MLX model repo.",
    )
    parser.add_argument("--reference-file", type=Path, help="Reference transcript for WER.")
    parser.add_argument("--repeat", type=int, default=1, help="Runs per provider.")
    parser.add_argument("--json-out", type=Path, help="Optional JSON report path.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.audio.exists():
        print(f"audio not found: {args.audio}", file=sys.stderr)
        return 2

    selected = [provider.strip() for provider in args.providers.split(",") if provider.strip()]
    unknown = [provider for provider in selected if provider not in PROVIDERS]
    if unknown:
        print(f"unknown providers: {', '.join(unknown)}", file=sys.stderr)
        return 2

    reference = args.reference_file.read_text(encoding="utf-8") if args.reference_file else None
    config = BenchConfig(
        audio=args.audio,
        audio_seconds=audio_duration(args.audio),
        language=args.language,
        parakeet_model=args.parakeet_model,
    )

    final_results: list[BenchResult] = []
    for provider_name in selected:
        provider = PROVIDERS[provider_name]
        runs = [provider(config)]
        for _ in range(max(0, args.repeat - 1)):
            if runs[0].status != "ok":
                break
            runs.append(provider(config))
        result = aggregate_results(runs)
        if result.wall_seconds:
            result.realtime_factor = config.audio_seconds / result.wall_seconds
        if reference and result.transcript:
            result.wer = word_error_rate(reference, result.transcript)
        final_results.append(result)

    print(f"Audio: {args.audio} ({config.audio_seconds:.2f}s)")
    print_table(final_results)

    if args.json_out:
        payload = {
            "audio": str(args.audio),
            "audio_seconds": config.audio_seconds,
            "language": config.language,
            "results": [result.as_json() for result in final_results],
        }
        args.json_out.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
                                 encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
