#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <input.mp4> [delogo=x:y:w:h] [device=cpu|mps|cuda] [output.mp4]

Examples:
  $0 input.mp4
  $0 input.mp4 delogo=x=895:y=1735:w=80:h=80
  $0 input.mp4 delogo=x=895:y=1735:w=80:h=80 device=mps
  $0 input.mp4 delogo=x=895:y=1735:w=80:h=80 custom_output.mp4
EOF
}

detect_device() {
  if [[ -n "${DEVICE:-}" ]]; then
    echo "$DEVICE"
    return
  fi
  if python -c "import torch; raise SystemExit(0 if torch.backends.mps.is_available() else 1)" 2>/dev/null; then
    echo "mps"
  elif python -c "import torch; raise SystemExit(0 if torch.cuda.is_available() else 1)" 2>/dev/null; then
    echo "cuda"
  else
    echo "cpu"
  fi
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
DEVICE=""
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
    device=*)
      DEVICE="${1#device=}"
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

INPUT_NAME="$(basename "$INPUT")"
INPUT_NAME="${INPUT_NAME%.*}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
WORK_DIR="output/${TIMESTAMP}-${INPUT_NAME}"

FRAMES_DIR="$WORK_DIR/frames"
CLEANED_DIR="$WORK_DIR/cleaned_frames"
MASK="$WORK_DIR/mask.png"
AUDIO="$WORK_DIR/audio.aac"
IOPAINT_CONFIG="$WORK_DIR/iopaint.json"
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
IOPAINT_DEVICE="$(detect_device)"

echo "==> Working directory: $WORK_DIR"
echo "==> Logo area: x=$LOGO_X y=$LOGO_Y w=$LOGO_W h=$LOGO_H"
echo "==> IOPaint device: $IOPAINT_DEVICE"
echo "==> Step 1/5: Extract frames from $INPUT"
mkdir -p "$FRAMES_DIR"
ffmpeg -y -i "$INPUT" "$FRAMES_DIR/%06d.png"

echo "==> Step 2/5: Extract audio"
ffmpeg -y -i "$INPUT" -vn -acodec copy "$AUDIO"

echo "==> Step 3/5: Create logo masks"
python make_mask.py "$WORK_DIR" --x "$LOGO_X" --y "$LOGO_Y" --w "$LOGO_W" --h "$LOGO_H" --width "$WIDTH" --height "$HEIGHT"

echo "==> Step 4/5: Run IOPaint batch clean"
mkdir -p "$CLEANED_DIR"
CROP_MARGIN=$((LOGO_W > LOGO_H ? LOGO_W / 4 : LOGO_H / 4))
CROP_MARGIN=$((CROP_MARGIN < 16 ? 16 : CROP_MARGIN))
CROP_MARGIN=$((CROP_MARGIN > 64 ? 64 : CROP_MARGIN))
cat > "$IOPAINT_CONFIG" <<EOF
{
  "hd_strategy": "Crop",
  "hd_strategy_crop_margin": $CROP_MARGIN
}
EOF
iopaint run \
  --model=lama \
  --device="$IOPAINT_DEVICE" \
  --config="$IOPAINT_CONFIG" \
  --image="$FRAMES_DIR" \
  --mask="$MASK" \
  --output="$CLEANED_DIR"

echo "==> Step 5/5: Rebuild video at ${FRAMERATE} fps -> $OUTPUT"
ffmpeg -y -framerate "$FRAMERATE" -i "$CLEANED_DIR/%06d.png" -i "$AUDIO" \
  -c:v libx264 -pix_fmt yuv420p -c:a copy "$OUTPUT"

echo "Done: $OUTPUT"
