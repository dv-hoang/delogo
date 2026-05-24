ffmpeg -framerate 60 -i cleaned_frames/%06d.png -i audio.aac \
-c:v libx264 -pix_fmt yuv420p -c:a copy iopaint.mp4