from PIL import Image, ImageDraw
import argparse
import os

parser = argparse.ArgumentParser(description="Create logo mask for IOPaint batch processing.")
parser.add_argument("work_dir", nargs="?", default=".", help="Work directory containing frames/")
parser.add_argument("--x", type=int, default=885, help="Logo x position")
parser.add_argument("--y", type=int, default=1728, help="Logo y position")
parser.add_argument("--w", type=int, default=115, help="Logo width")
parser.add_argument("--h", type=int, default=95, help="Logo height")
parser.add_argument("--width", type=int, default=1080, help="Frame width")
parser.add_argument("--height", type=int, default=1920, help="Frame height")
args = parser.parse_args()

frames_dir = os.path.join(args.work_dir, "frames")
mask_path = os.path.join(args.work_dir, "mask.png")

if not os.path.isdir(frames_dir):
    raise SystemExit(f"Frames directory not found: {frames_dir}")

mask = Image.new("L", (args.width, args.height), 0)
draw = ImageDraw.Draw(mask)
draw.rectangle([args.x, args.y, args.x + args.w, args.y + args.h], fill=255)
mask.save(mask_path)

frame_count = len([f for f in os.listdir(frames_dir) if f.endswith(".png")])
print(f"Created mask for {frame_count} frames -> {mask_path}")
