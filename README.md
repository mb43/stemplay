# Stem Player

A simple, client-side web app for playing stem-split audio files. Load a folder of stems, then mute, solo, and mix individual tracks for each song. All audio stays on your machine - nothing is uploaded.

**[Live App](https://mb43.github.io/stemplayer/)** (after enabling GitHub Pages)

## Features

- Load a folder of stem-split songs (FLAC, WAV, MP3, OGG, AAC, M4A)
- Synchronized playback of all stems per song
- Mute / Solo / Volume per stem
- Seek bar and transport controls
- Keyboard shortcut: Space = play/pause
- Works entirely in the browser - no server needed
- Dark theme, responsive layout

## How to Use

### 1. Split your songs into stems

Use one of these options on your Mac:

**Option A - Demucs (free, command-line):**
```bash
pip install demucs
demucs --out ./stems *.flac
```
This creates `stems/htdemucs/songname/{vocals,drums,bass,other}.wav` for each file.

**Option B - Logic Pro stem splitter:**
Import your FLAC files into Logic Pro, use the built-in Stem Splitter, and export each stem track.

### 2. Organize your stems

The app expects this folder structure:
```
my-stems/
  Song One/
    vocals.wav
    drums.wav
    bass.wav
    other.wav
  Song Two/
    vocals.flac
    drums.flac
    bass.flac
    other.flac
```
Each subfolder = one song. Each file inside = one stem. Demucs output already follows this structure.

### 3. Open the app and load your folder

Open `index.html` (or the GitHub Pages URL), click the import area, and select your stems folder. Pick a song from the sidebar, then mute/solo/adjust volume on any stem.

## Hosting on GitHub Pages

1. Go to your repo **Settings > Pages**
2. Set Source to **Deploy from a branch**
3. Select **main** branch, **/ (root)** folder
4. Save - your app will be live at `https://<username>.github.io/stemplayer/`

## Renaming this repo

To rename from `win11powershelltest` to `stemplayer`:
1. Go to repo **Settings > General**
2. Change the **Repository name** to `stemplayer`
3. Click **Rename**

GitHub automatically redirects the old URL.

## Space & Time Estimates for 50 Songs

Assuming ~4 minutes average per song, 4 stems each (vocals, drums, bass, other):

| Format | Per Song (4 stems) | 50 Songs |
|--------|-------------------|----------|
| WAV 44.1kHz 16-bit | ~160 MB | **~8 GB** |
| FLAC (lossless) | ~80-110 MB | **~4-5.5 GB** |
| OGG/MP3 320kbps | ~38 MB | **~1.9 GB** |

**Processing time with Demucs:**
- Apple Silicon Mac (M1-M4): ~1-2 min/song = **~50-100 min for 50 songs**
- Intel Mac: ~3-8 min/song = **~150-400 min for 50 songs**

Note: Audio files are loaded locally from your machine into the browser. They are **not** stored in the GitHub repo, so repo size limits don't apply.
