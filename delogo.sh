#!/bin/bash
# remove name extension from input file 
input_file="$1"
output_file="${input_file%.*}_delogo.mp4" 
ffmpeg -i $input_file -vf "delogo=x=895:y=1735:w=80:h=80:show=0" -c:a copy "$output_file"