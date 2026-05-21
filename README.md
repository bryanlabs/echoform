# Echoform

Echoform is a macOS app that turns whatever audio is playing on your Mac into
a calm, beautiful visualization. It taps your system audio output and renders
it as ambient, audio-reactive visuals, so whatever you are listening to
(music, a podcast, an audiobook, a call) you have something gentle to look at
instead of reaching for a feed, a game, or another screen.

It is built to hold your eyes without taking your attention: ambient, not
interactive; glanceable, not readable; audio-reactive, not content-competing.
The point is visual interest while you listen, not a second task.

## What it does

- Captures whatever is playing through the system audio output, locally.
- Renders it as one of six calm visual modes (bars, waveform, spectral heat,
  pulse field, flow field, or a combined view).
- Optionally shows a delayed, on-device caption layer of the speech.
- Themeable, full-screen capable, and driven by a few quiet keyboard shortcuts.

Nothing is recorded, saved, or sent anywhere. Echoform makes no network calls.

## Requirements

- macOS 14 or later (built and tested on macOS 26).
- To build from source: Xcode 26 with the Swift 6.2 toolchain.

## Build and install

```sh
./Scripts/install.sh
```

This builds a signed `Echoform.app`, installs it to `/Applications`, and
installs an `echoform` launcher into `~/bin`.

- `./Scripts/package-app.sh` builds the signed app into `dist/` without installing.
- `./Scripts/make-icon.sh` regenerates the app icon.

## First run: grant Screen Recording access

macOS routes system audio through the Screen Recording permission, so
ScreenCaptureKit (which Echoform uses to capture audio) needs it even though
Echoform only ever captures audio, never video.

1. Launch Echoform. It shows a permission screen.
2. Click **Open System Settings** (or open System Settings ›
   Privacy & Security › Screen Recording).
3. Enable **Echoform** in the list, and authenticate when macOS asks.
4. Quit and reopen Echoform.

The grant is keyed to the app's stable signing identity, so it survives
rebuilds. You only do this once.

## Controls

Controls are sparse and mostly hidden. Move the mouse to reveal a hint bar.

| Key      | Action                            |
|----------|-----------------------------------|
| `1`–`6`  | Switch visual mode                |
| `Space`  | Pause / resume                    |
| `F`      | Toggle full screen                |
| `Esc`    | Leave full screen                 |
| `[` `]`  | Decrease / increase intensity     |
| `B`      | Cycle brightness                  |
| `←` `→`  | Cycle theme                       |
| `C`      | Open the theme / color panel      |
| `T`      | Toggle captions                   |
| `,` `.`  | Decrease / increase delay         |
| `Cmd+Q`  | Quit                              |

## Visual modes

1. **Bars** — symmetric loudness and frequency bars.
2. **Wave Ribbon** — a smooth, glowing waveform ribbon.
3. **Spectral Heat** — a slow-scrolling spectrogram.
4. **Pulse Field** — breathing shapes driven by loudness and bass.
5. **Flow Field** — a slowly flowing vector field shaped by mids and treble.
6. **Combined** — heat, pulse, and bars layered into one ambient view.

## Captions and the delay

Press `T` to show a caption layer. Speech is transcribed on-device (nothing
leaves the Mac) and shown as calm, low-contrast text in the lower window.

On-device recognition runs a couple of seconds behind the audio, so the `,`
and `.` keys set a delay (0 to 10 seconds) that holds back the whole
visualization, not just the words. At 0 the bars run in real time and the
captions trail behind by the recognition lag. Raise the delay and the bars are
held back too, so once it passes that lag the words line up with the bars.

## Themes

The `←` and `→` keys cycle through Classic, Cyberpunk (pink and purple),
Aurora (greens), Ember (warm reds), and your Custom theme. Press `C` to open
the theme panel: preset swatches and three color wells for the custom theme
(each opens the macOS color picker).

## Preview mode

To see the visuals without playing audio and without granting any permission:

```sh
echoform --demo
```

Add `--text` to start with the caption layer on. Demo mode feeds a synthetic
signal through the renderer, useful for trying modes, themes, and brightness.

## Privacy

Audio is analyzed and transcribed locally in real time and never leaves the
machine. Echoform makes no network calls and never records, saves, or uploads
audio or transcripts.

## Project layout

- `Sources/EchoformKit/` — the engine library: capture, analysis, observable
  state, speech, and the SwiftUI renderers.
- `Sources/Echoform/` — the app entry point.
- `Tests/EchoformKitTests/` — unit tests for the analysis layer.
- `Scripts/` — build, sign, install, and icon scripts.
