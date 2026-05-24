# logo-remove

Remove a fixed logo/watermark from video using [IOPaint](https://github.com/Sanster/IOPaint) (LaMA inpainting) and ffmpeg.

## Sample videos

Compare results on the same source clip:

| File | Method | Command |
|------|--------|---------|
| [`input.mp4`](input.mp4) | Original (with logo) | — |
| [`ffmpeg_delogo.mp4`](ffmpeg_delogo.mp4) | ffmpeg delogo (blur) | `./delogo.sh input.mp4` |
| [`iopaint.mp4`](iopaint.mp4) | IOPaint + ffmpeg rebuild | `./run.sh input.mp4` |

## Prerequisites

- [ffmpeg](https://ffmpeg.org/) (includes `ffprobe`)
- Python **3.12** (required — iopaint/gradio needs `pillow<11`, which does not work on Python 3.14)

## Setup

```bash
python3.12 -m venv iopaint-env
source iopaint-env/bin/activate
pip install -r requirements.txt
```

## Usage

```bash
./run.sh input.mp4
./run.sh input.mp4 delogo=x=895:y=1735:w=80:h=80
./run.sh input.mp4 delogo=x=895:y=1735:w=80:h=80 custom_output.mp4
```

### Logo coordinates

Use the same `delogo=x:y:w:h` format as ffmpeg's delogo filter. Find coordinates by previewing with ffmpeg:

```bash
ffmpeg -i input.mp4 -vf "delogo=x=895:y=1735:w=80:h=80:show=1" -t 1 -f null -
```

If omitted, default mask values are used (`x=885 y=1728 w=115 h=95`).

### Output layout

Each run creates a work folder named after the input file:

```
input/
├── frames/           # extracted frames
├── masks/            # logo masks
├── cleaned_frames/   # inpainted frames
├── audio.aac         # extracted audio
└── output_clean.mp4  # final video
```

## Pipeline steps

`run.sh` runs these steps automatically:

1. Extract frames → `{name}/frames/`
2. Extract audio → `{name}/audio.aac`
3. Create masks → `make_mask.py`
4. Batch inpaint (LaMA, CPU) → `{name}/cleaned_frames/`
5. Rebuild video with original framerate and audio

Step 4 is slow on CPU (~2–3 s/frame). A 30 s 60 fps video can take 1–2 hours.

## Quick alternative (ffmpeg blur)

For a faster but lower-quality result, use ffmpeg's built-in delogo filter:

```bash
./delogo.sh input.mp4
```

## Files

| File | Description |
|------|-------------|
| `run.sh` | Full IOPaint pipeline |
| `make_mask.py` | Generate logo masks for IOPaint |
| `delogo.sh` | Fast ffmpeg delogo (blur) |
| `requirements.txt` | Python dependencies |
