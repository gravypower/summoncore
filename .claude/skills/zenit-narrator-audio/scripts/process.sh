#!/usr/bin/env bash
# Processes the rendered takes into Ogg Vorbis and builds the combined read.
# Run from the folder containing narrator_backstory_01.wav .. _08.wav (needs ffmpeg).
set -euo pipefail

AF="highpass=f=70,equalizer=f=160:t=q:w=1:g=2.5,equalizer=f=5500:t=q:w=1:g=-2,acompressor=threshold=-20dB:ratio=2.5:attack=15:release=250,loudnorm=I=-18:TP=-2"

# each take
for f in narrator_backstory_0*.wav; do
  ffmpeg -y -loglevel error -i "$f" -af "$AF" -c:a libvorbis -q:a 4 "${f%.wav}.ogg"
done

# combined read: join the raw WAVs in order, then process the whole thing once
for f in narrator_backstory_0*.wav; do echo "file '$f'"; done > list.txt
ffmpeg -y -loglevel error -f concat -safe 0 -i list.txt -af "$AF" \
  -c:a libvorbis -q:a 4 narrator_backstory_full.ogg
rm -f list.txt
ls -la narrator_backstory_*.ogg
