from PIL import Image, ImageDraw
import argparse
import os

parser = argparse.ArgumentParser(description="Create logo masks for IOPaint batch processing.")
parser.add_argument("work_dir", nargs="?", default=".", help="Work directory containing frames/")
parser.add_argument("--x", type=int, default=885, help="Logo x position")
parser.add_argument("--y", type=int, default=1728, help="Logo y position")
parser.add_argument("--w", type=int, default=115, help="Logo width")
parser.add_argument("--h", type=int, default=95, help="Logo height")
parser.add_argument("--width", type=int, default=1080, help="Frame width")
parser.add_argument("--height", type=int, default=1920, help="Frame height")
args = parser.parse_args()

frames_dir = os.path.join(args.work_dir, "frames")
masks_dir = os.path.join(args.work_dir, "masks")

os.makedirs(masks_dir, exist_ok=True)

mask = Image.new("L", (args.width, args.height), 0)
draw = ImageDraw.Draw(mask)
draw.rectangle([args.x, args.y, args.x + args.w, args.y + args.h], fill=255)

frame_count = len([f for f in os.listdir(frames_dir) if f.endswith(".png")])

for i in range(1, frame_count + 1):
    mask.save(os.path.join(masks_dir, f"{i:06d}.png"))

print(f"Created {frame_count} masks.")
