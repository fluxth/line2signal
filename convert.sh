#!/bin/bash -e

# Create `converted` directory alongside `data` directory first!
# Run this in the `data` directory

IN_FILE="./$1"
OUT_FILE="../converted/$1"

echo "Processing $IN_FILE..."

IFS=', ' read w h <<< $(ffprobe -hide_banner -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$IN_FILE" 2>&1)
echo "Original: ${w}x${h}"

LONGEST=$w
[[ $h -gt $LONGEST ]] && LONGEST=$h

FORMAT=png
LOOP=''
if ffprobe -hide_banner "$IN_FILE" 2>&1 | grep apng > /dev/null; then
    echo "Sticker is animated"
    FORMAT=apng
    LOOP='-plays 0'
fi

# Pad 10%
LONGEST_PADDED=$LONGEST
if [[ "$2" == "pad" ]]; then
    LONGEST_PADDED=$(echo "$LONGEST*1.1/1" | bc)
fi
echo "Longest Side: ${LONGEST_PADDED}"


PAD_WIDTH=$(echo "($LONGEST_PADDED-$w)/2" | bc)
PAD_HEIGHT=$(echo "($LONGEST_PADDED-$h)/2" | bc)
echo "Pad: ${PAD_WIDTH}x${PAD_HEIGHT}"

ffmpeg -v error -i "$IN_FILE" $LOOP -vf "scale=${LONGEST_PADDED}x${LONGEST_PADDED}:force_original_aspect_ratio=decrease,format=rgba,pad=${LONGEST_PADDED}:${LONGEST_PADDED}:-${PAD_WIDTH}:-${PAD_HEIGHT}:color=#00000000" -f $FORMAT "$OUT_FILE"
