#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <input.mp4> [delogo=x:y:w:h] [output.mp4]

Examples:
  $0 input.mp4
  $0 input.mp4 delogo=x=895:y=1735:w=80:h=80
  $0 input.mp4 delogo=x=895:y=1735:w=80:h=80 custom_output.mp4
EOF
}

parse_delogo() {
  local spec="${1#delogo=}"
  local pair key val
  IFS=':' read -ra pairs <<< "$spec"
  for pair in "${pairs[@]}"; do
    key="${pair%%=*}"
    val="${pair#*=}"
    case "$key" in
      x) LOGO_X="$val" ;;
      y) LOGO_Y="$val" ;;
      w) LOGO_W="$val" ;;
      h) LOGO_H="$val" ;;
    esac
  done
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

INPUT="$1"
shift

OUTPUT=""
DELOGO=""
LOGO_X=885
LOGO_Y=1728
LOGO_W=115
LOGO_H=95

while [[ $# -gt 0 ]]; do
  case "$1" in
    delogo=*)
      DELOGO="$1"
      parse_delogo "$DELOGO"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      OUTPUT="$1"
      shift
      ;;
  esac
done

WORK_DIR="$(basename "$INPUT")"
WORK_DIR="${WORK_DIR%.*}"

FRAMES_DIR="$WORK_DIR/frames"
MASKS_DIR="$WORK_DIR/masks"
CLEANED_DIR="$WORK_DIR/cleaned_frames"
AUDIO="$WORK_DIR/audio.aac"
OUTPUT="${OUTPUT:-$WORK_DIR/output_clean.mp4}"

if [[ ! -f "$INPUT" ]]; then
  echo "Input video not found: $INPUT" >&2
  exit 1
fi

mkdir -p "$WORK_DIR"

if [[ -d "iopaint-env/bin" ]]; then
  # shellcheck disable=SC1091
  source iopaint-env/bin/activate
fi

FRAMERATE="$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$INPUT" | awk -F/ '{if ($2) printf "%.2f", $1/$2; else print $1}')"
FRAMERATE="${FRAMERATE%.*}"
WIDTH="$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$INPUT")"
HEIGHT="$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$INPUT")"

echo "==> Working directory: $WORK_DIR"
echo "==> Logo area: x=$LOGO_X y=$LOGO_Y w=$LOGO_W h=$LOGO_H"
echo "==> Step 1/5: Extract frames from $INPUT"
mkdir -p "$FRAMES_DIR"
ffmpeg -y -i "$INPUT" "$FRAMES_DIR/%06d.png"

echo "==> Step 2/5: Extract audio"
ffmpeg -y -i "$INPUT" -vn -acodec copy "$AUDIO"

echo "==> Step 3/5: Create logo masks"
python make_mask.py "$WORK_DIR" --x "$LOGO_X" --y "$LOGO_Y" --w "$LOGO_W" --h "$LOGO_H" --width "$WIDTH" --height "$HEIGHT"

echo "==> Step 4/5: Run IOPaint batch clean"
mkdir -p "$CLEANED_DIR"
iopaint run \
  --model=lama \
  --device=cpu \
  --image="$FRAMES_DIR" \
  --mask="$MASKS_DIR" \
  --output="$CLEANED_DIR"

echo "==> Step 5/5: Rebuild video at ${FRAMERATE} fps -> $OUTPUT"
ffmpeg -y -framerate "$FRAMERATE" -i "$CLEANED_DIR/%06d.png" -i "$AUDIO" \
  -c:v libx264 -pix_fmt yuv420p -c:a copy "$OUTPUT"

echo "Done: $OUTPUT"
