# Echoform

[![CI](https://github.com/bryanlabs/echoform/actions/workflows/ci.yml/badge.svg)](https://github.com/bryanlabs/echoform/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-lightgrey.svg)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)

Echoform is a macOS app that turns whatever audio is playing on your Mac into
a calm, beautiful visualization. It taps your system audio output and renders
it as ambient, audio-reactive visuals, so whatever you are listening to
(music, a podcast, an audiobook, a call) you have something gentle to look at
instead of reaching for a feed, a game, or another screen.

It is built to hold your eyes without taking your attention: ambient, not
interactive; glanceable, not readable; audio-reactive, not content-competing.
The point is visual interest while you listen, not a second task.

![Echoform in Bars mode with the Cyberpunk theme and live on-device captions](docs/screenshots/cyberpunk-captions.png)

*Bars mode with the Cyberpunk theme and on-device captions.*

## What it does

- Captures whatever is playing through the system audio output, locally.
- Renders it as one of six calm visual modes (bars, waveform, spectral heat,
  pulse field, flow field, or a combined view).
- Optionally shows a delayed, on-device caption layer, with optional
  on-device translation between a dozen major languages.
- Themeable, full-screen capable, and driven by a few quiet keyboard shortcuts.

Nothing is recorded, saved, or sent anywhere. Echoform makes no network calls.

## Requirements

- macOS 15 or later (built and tested on macOS 26).
- To build from source: Xcode 26 with the Swift 6.2 toolchain.

## Build and install

Building from source is the recommended way to run Echoform. You can read
every line first, and a build you compiled yourself is not quarantined, so it
opens with no Gatekeeper prompt (see "Permissions and trust" below).

```sh
git clone https://github.com/bryanlabs/echoform.git
cd echoform
./Scripts/install.sh
```

This builds `Echoform.app`, installs it to `/Applications`, and installs an
`echoform` launcher into `~/bin`. The build is ad-hoc signed. If you have an
Apple Development certificate it is used automatically instead, which keeps
macOS from re-asking for Screen Recording access on every rebuild.

- `./Scripts/package-app.sh` builds the app into `dist/` without installing.
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

macOS remembers the grant, so you only do this once.

## Controls

Controls are sparse and mostly hidden. Move the mouse to reveal a hint bar.

| Key      | Action                            |
|----------|-----------------------------------|
| `1`-`6`  | Switch visual mode                |
| `Space`  | Pause / resume                    |
| `F`      | Toggle full screen                |
| `Esc`    | Leave full screen                 |
| `[` `]`  | Decrease / increase intensity     |
| `B`      | Cycle brightness                  |
| `←` `→`  | Cycle theme                       |
| `C`      | Open the theme / color panel      |
| `T`      | Toggle captions                   |
| `L`      | Open the captions panel           |
| `,` `.`  | Decrease / increase delay         |
| `Cmd+Q`  | Quit                              |

## Visual modes

1. **Bars.** Symmetric loudness and frequency bars.
2. **Wave Ribbon.** A smooth, glowing waveform ribbon.
3. **Spectral Heat.** A slow-scrolling spectrogram.
4. **Pulse Field.** Breathing shapes driven by loudness and bass.
5. **Flow Field.** A slowly flowing vector field shaped by mids and treble.
6. **Combined.** Heat, pulse, and bars layered into one ambient view.

## Captions and the delay

Press `T` to show a caption layer. Speech is transcribed on-device (nothing
leaves the Mac) and shown as calm, low-contrast text in the lower window.

On-device recognition runs a couple of seconds behind the audio, so the `,`
and `.` keys set a delay (0 to 10 seconds) that holds back the whole
visualization, not just the words. At 0 the bars run in real time and the
captions trail behind by the recognition lag. Raise the delay and the bars are
held back too, so once it passes that lag the words line up with the bars.

Press `L` to open the captions panel. It picks the spoken language for
recognition (a dozen major languages) and an optional language to translate
into. With translation on, each finished sentence is recognized in the spoken
language and then translated on-device before it appears, so you can, for
example, follow a meeting held in Korean as English captions. Translation uses
Apple's Translation framework; the first time you use a language pair, macOS
downloads that pair once.

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

## Permissions and trust

Echoform asks for two macOS permissions, and only those two.

- **Screen Recording.** macOS routes system-audio capture through the Screen
  Recording permission, so ScreenCaptureKit needs it. Echoform uses it only to
  read the audio that is already playing. It never captures, shows, or saves
  the screen or any video. Granting it is a one-time step (see "First run").
- **Speech Recognition.** Requested only when you turn captions on (`T`). By
  default Echoform recognizes speech on-device, so audio stays on the Mac. A
  language with no on-device model does not transcribe until you install that
  model or turn off **On-device only** in the captions panel (`L`). With that
  off, recognition for such a language uses Apple's online speech service, the
  same one macOS Dictation uses.

Echoform itself makes no network calls and never records, saves, or uploads
audio, transcripts, or anything else. Audio is analyzed in memory in real time
and then discarded. Recognition and translation run on-device by default. The
exceptions: macOS downloads a translation language pack the first time you pick
a new pair, and, with **On-device only** off, recognition for a language with
no local model uses Apple's online speech service.

### Why there is no notarized download

An app that opens with no warning on any Mac has to be notarized by Apple,
which requires a paid Apple Developer Program membership. Echoform is a free,
zero-budget project and is not enrolled, so it is not notarized.

That is why building from source is the recommended path: the whole app is in
this repository, you can audit it, and a build you compiled locally is not
quarantined, so it opens with no Gatekeeper prompt.

If a release attaches a pre-built `Echoform.app`, macOS blocks it on first
launch because it is not notarized. To open it anyway, launch it once, then
open System Settings › Privacy & Security, find the note about Echoform being
blocked, and click **Open Anyway**. Or clear the download quarantine first:

```sh
xattr -dr com.apple.quarantine /path/to/Echoform.app
```

## Project layout

- `Sources/EchoformKit/` is the engine library: capture, analysis, observable
  state, speech, and the SwiftUI renderers.
- `Sources/Echoform/` is the app entry point.
- `Tests/EchoformKitTests/` holds unit tests for the analysis layer.
- `Scripts/` holds the build, sign, install, and icon scripts.

## License

MIT. See [LICENSE](LICENSE).
