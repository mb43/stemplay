# Stem Player

Split your stereo FLAC files into stems (vocals, drums, bass, other), then play and mix them in the browser. Mute, solo, and adjust volume for each stem per song. All audio stays on your machine.

**[Live App](https://mb43.github.io/stemplayer/)** (after enabling GitHub Pages)

## Quick Start

### 1. Split your FLACs into stems

Open Terminal on your Mac and run:

```bash
# One-time setup
pip3 install demucs

# Split all your FLAC files
demucs --out ~/stems ~/Music/*.flac
```

Or use the included batch script (shows progress, auto-installs Demucs):

```bash
./split-stems.sh ~/Music ~/stems
```

This creates `~/stems/SongName/{vocals,drums,bass,other}.wav` for each FLAC file.

**Alternative:** Use Logic Pro's built-in Stem Splitter and export each track to a subfolder per song.

### 2. Open Stem Player and load your stems folder

Open `index.html` (or the GitHub Pages URL), click import, and select your `~/stems` folder. Pick any song from the sidebar, then mute/solo/adjust volume on individual stems.

## What's Included

| File | Purpose |
|------|---------|
| `index.html` | The Stem Player web app (single file, no dependencies) |
| `split-stems.sh` | Mac shell script to batch-split FLACs using Demucs |

## Features

- Batch split FLAC files into stems via included script
- Synchronized multi-stem playback via Web Audio API
- Mute / Solo / Volume per stem
- Seek bar, play/pause/stop transport
- Space bar shortcut for play/pause
- Click-to-copy terminal commands in the app
- Dark theme, responsive layout
- 100% client-side - no uploads, no server

## Expected Folder Structure

```
stems/
  Song One/
    vocals.wav
    drums.wav
    bass.wav
    other.wav
  Song Two/
    vocals.wav
    drums.wav
    bass.wav
    other.wav
```

Demucs output follows this structure automatically. The script reorganizes it so it's ready to load directly.

## Space & Time Estimates (50 Songs)

Assuming ~4 min average per song, 4 stems each:

| Format | Per Song | 50 Songs |
|--------|----------|----------|
| WAV 44.1kHz 16-bit | ~160 MB | **~8 GB** |
| FLAC (lossless) | ~80-110 MB | **~4-5.5 GB** |
| OGG/MP3 320kbps | ~38 MB | **~1.9 GB** |

**Stem splitting time (Demucs):**
- Apple Silicon (M1-M4): ~1-2 min/song = **~1-2 hours for 50 songs**
- Intel Mac: ~3-8 min/song = **~3-7 hours for 50 songs**

Audio files are loaded locally from your machine into the browser - they are **not** stored in the GitHub repo.

## Hosting on GitHub Pages

1. Go to repo **Settings > Pages**
2. Source: **Deploy from a branch**
3. Branch: **main**, folder: **/ (root)**
4. Your app will be live at `https://<username>.github.io/stemplayer/`

## Renaming This Repo

To rename from `win11powershelltest` to `stemplayer`:

1. Go to repo **Settings > General**
2. Change **Repository name** to `stemplayer`
3. Click **Rename**

GitHub auto-redirects the old URL.
