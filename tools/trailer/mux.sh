#!/usr/bin/env bash
# Mux build/trailer_silent.mkv + build/score.wav -> build/BLOCKMANIA_trailer.mp4 (Steam spec:
# H.264 High 1080p60, >5 Mbps, AAC stereo). Audio is loudness-normalized to -14 LUFS / -1 dBTP.
set -euo pipefail
cd "$(dirname "$0")/build"
J=$(ffmpeg -hide_banner -nostats -i score.wav -af loudnorm=I=-14:TP=-1.0:LRA=11:print_format=json -f null - 2>&1 | sed -n '/{/,/}/p')
g() { echo "$J" | grep "\"$1\"" | sed 's/.*: "\(.*\)".*/\1/'; }
AF="loudnorm=I=-14:TP=-1.0:LRA=11:measured_I=$(g input_i):measured_TP=$(g input_tp):measured_LRA=$(g input_lra):measured_thresh=$(g input_thresh):offset=$(g target_offset):linear=true,aresample=48000"
ffmpeg -y -hide_banner -loglevel error -i trailer_silent.mkv -i score.wav -map 0:v -map 1:a \
  -c:v libx264 -preset slow -crf 15 -maxrate 30M -bufsize 60M -profile:v high -level 4.2 -pix_fmt yuv420p \
  -x264-params keyint=120:min-keyint=60 -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
  -af "$AF" -c:a aac -b:a 320k -ac 2 -movflags +faststart -shortest BLOCKMANIA_trailer.mp4
ffprobe -v error -show_entries format=duration,bit_rate -show_entries stream=codec_name,width,height,r_frame_rate -of compact BLOCKMANIA_trailer.mp4
