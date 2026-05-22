# Transcription Benchmarks

Date: 2026-05-22

Machine: Apple M4 Pro, 48 GB RAM

This benchmark is for candidate speech-to-text engines that could eventually
replace or augment the current Apple Speech caption path. It measures file
transcription throughput, not live streaming latency inside Echoform.

## Providers

- Apple Speech: currently integrated in the app for live captions.
- Parakeet MLX: local `mlx-community/parakeet-tdt-0.6b-v3`, run through
  `parakeet-mlx`.
- xAI Grok STT: hosted REST or WebSocket speech-to-text through
  `https://api.x.ai/v1/stt`.
- Groq Whisper: hosted `whisper-large-v3-turbo` and `whisper-large-v3`, plus
  `whisper-large-v3` translation for Spanish-to-English checks.

Provider references:

- xAI Grok STT docs: https://docs.x.ai/developers/model-capabilities/audio/speech-to-text
- Groq Speech-to-Text docs: https://console.groq.com/docs/speech-to-text
- NVIDIA Parakeet model card: https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3
- Parakeet MLX package instructions: https://huggingface.co/mlx-community/parakeet-tdt-0.6b-v3

## Test Audio

The current smoke benchmark uses a 21.29 second Spanish sample generated with
macOS `say` using the `Mónica` Spanish voice and converted to 16 kHz mono WAV.

```sh
BENCH=/tmp/echoform-bench
mkdir -p "$BENCH"
say -v Mónica -r 130 -o "$BENCH/spanish-sample.aiff" \
  "Amor, qué vas a pedir? Solo voy a pedir una ensalada. Después caminamos por el parque y hablamos de la historia que escuchamos en el audiolibro. La noche estaba tranquila y el narrador habló lentamente sobre una ciudad junto al mar. Cada capítulo tenía música suave y muchos detalles sobre la familia, el viaje y los recuerdos. Al final volvimos a casa y seguimos escuchando con calma."
ffmpeg -hide_banner -loglevel error -y -i "$BENCH/spanish-sample.aiff" \
  -ac 1 -ar 16000 "$BENCH/spanish-sample.wav"
```

## Command

```sh
Scripts/benchmark-transcribers.py /tmp/echoform-bench/spanish-sample.wav \
  --language es \
  --reference-file /tmp/echoform-bench/spanish-reference.txt \
  --repeat 3 \
  --json-out /tmp/echoform-bench/benchmark.json
```

Set these environment variables to include hosted providers:

- `XAI_API_KEY` for xAI Grok STT.
- `GROQ_API_KEY` for Groq Whisper.

`XAI_API_KEY` was read from Dan's Personal vault after attended 1Password
approval. `GROQ_API_KEY` was saved in the `Codex Automation` vault and read
through `/Users/danb/.local/bin/op-codex`.

## Results

| Provider | Status | Runs | Wall s | Real-time | WER | Notes |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| parakeet-mlx | ok | 3 | 1.17 | 18.1x | 0.0% | Hot CLI run with cached model |
| xai-grok-stt | ok | 3 | 1.29 | 16.5x | 0.0% | Hosted xAI STT endpoint |
| groq-whisper-large-v3-turbo | ok | 3 | 1.09 | 19.5x | 0.0% | Hosted Groq audio transcription endpoint |
| groq-whisper-large-v3 | ok | 3 | 1.20 | 17.7x | 0.0% | Hosted Groq audio transcription endpoint |
| groq-whisper-large-v3-translate | ok | 3 | 1.03 | 20.7x | 0.0% | Groq translations endpoint, same-language output on this sample |

Parakeet's first cold run took 43.71 seconds because it included package and
model setup. After that cache was warm, the latest repeat runs were 1.13, 1.17,
and 1.19 seconds for the 21.29 second sample. One measured hot run used about
1.58 GB maximum resident memory.

xAI Grok STT repeat runs were 1.46, 1.29, and 1.04 seconds for the same sample.
Groq Whisper Large v3 Turbo repeat runs were 1.09, 1.13, and 1.09 seconds.
Groq Whisper Large v3 repeat runs were 1.21, 1.18, and 1.20 seconds. All of
those matched the Spanish reference transcript on this generated sample, but
the hosted providers are network round trips rather than local paths.

## Readout

Parakeet is clearly fast enough for local file throughput on this Mac. The open
question is live-caption ergonomics: Echoform would need either a Python/MLX
sidecar using Parakeet's streaming API or a native Swift/Core ML path before it
can replace Apple Speech in the visualizer.

Grok and Groq are viable hosted fallback candidates. xAI documents a WebSocket
streaming endpoint with partial transcripts, which matters if Echoform later
adds a cloud live-caption engine. Groq's `whisper-large-v3-turbo` was the
fastest hosted transcription endpoint in this smoke test and edged out the
latest Parakeet CLI run, but Parakeet remains the strongest offline candidate
because it avoids network dependency after model setup.

The Groq translations endpoint returned a Spanish transcript on this sample, so
that row should not be treated as proof of Spanish-to-English translation.
