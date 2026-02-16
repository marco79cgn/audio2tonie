# 🎵 audio2tonie

A fast and easy way to transcode audio files and podcast episodes to a format playable by Toniebox.

This fork is based on [opus2tonie.py](https://github.com/bailli/opus2tonie) but packaged as a convenient Docker container, eliminating the need to manually install dependencies like ffmpeg, Python, and Google Protobuf.

***

## 🚀 Installation 

### Option 1: Use prebuilt image (recommended)

```bash
docker pull ghcr.io/marco79cgn/audio2tonie
```

### Option 2: Build from source

```bash
git clone https://github.com/marco79cgn/audio2tonie.git
cd audio2tonie
docker build -t audio2tonie .
```

***

## 📖 Usage

Run this container on-demand to convert your audio files. Mount your host directory containing audio files into the container's `/data` folder.

### Basic Syntax

```bash
docker run --rm -v $(pwd):/data [IMAGE ID] transcode \
    -s/--source SOURCE \
    [-o/--output OUTPUT] \
    [-r/--recursive]
```

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `-s/--source SOURCE` | ✅ Yes | Input source: file, folder, list (*.lst), or URL |
| `-o/--output OUTPUT` | ❌ No | Output filename (default: same as input with .taf extension) |
| `-r/--recursive` | ❌ No | Creates a .taf file for each subfolder recursively |

***

### 🌐 Online Sources

**Download from ARD Audiothek**
```bash
docker run --rm -v $(pwd):/data audio2tonie transcode \
    -s "https://www.ardaudiothek.de/episode/urn:ard:episode:4f223e3b7c1dfe52/"
```
→ Output: `Unser Sandmännchen - Raketenflieger Timmi_ Der Traumplanet.taf`

**Download from Podtail**
```bash
docker run --rm -v $(pwd):/data audio2tonie transcode \
    -s "https://podtail.com/podcast/bits-und-so/bits-und-so-990-it-begins-to-learn-at-a-geometric-/"
```
→ Downloads and converts any podcast episode from podtail.com

***

## 💡 Examples

### 📁 Local Files

**Convert a single file**
```bash
docker run --rm -v $(pwd):/data audio2tonie transcode -s /data/audiobook.mp3
```
→ Output: `audiobook.taf`

**Convert with custom output name**
```bash
docker run --rm -v $(pwd):/data audio2tonie transcode -s /data/audiobook.mp3 -o /data/lullaby.taf
```
→ Output: `lullaby.taf`

**Convert entire folder (with chapters)**
```bash
docker run --rm -v $(pwd):/data audio2tonie transcode -s /data/sandmann
```
→ Output: `sandmann.taf` (with chapters for each file)

**Convert subfolders recursively**
```bash
# Directory structure:
# ├── Episode 01/
# ├── Episode 02/
# └── Episode 03/

docker run --rm -v $(pwd):/data audio2tonie transcode -s /data -r
```
→ Output: `Episode 01.taf`, `Episode 02.taf`, `Episode 03.taf`

**Convert from a playlist file**
```bash
# MyFavoriteList.lst:
# audio.mp3
# music.m4a
# news.opus
# trailer.mp3

docker run --rm -v $(pwd):/data audio2tonie transcode -s /data/MyFavoriteList.lst
```
→ Output: `MyFavoriteList.taf` (with 4 chapters)

***

## ℹ️ Additional Information

### Chapters
When using a list or folder(s) as source, chapters will be created automatically for easier navigation on your Toniebox.

### Useful Resources
* [Toniebox Audio File Format](https://github.com/toniebox-reverse-engineering/toniebox/wiki/Audio-file-format)
* [Original opus2tonie Source](https://github.com/bailli/opus2tonie)

***

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!
