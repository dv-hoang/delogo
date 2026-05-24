ffmpeg -framerate 30 -i cleaned_frames/%06d.png -i audio.aac \
-c:v libx264 -pix_fmt yuv420p -c:a copy output_clean.mp4