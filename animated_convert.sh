#!/bin/bash -e

FFMPEG_FLAGS='-hide_banner -v error'

mkdir -p output
for IN_FILE in $(ls *.png); do
#IN_FILE='7875119.png'
    FPS=$(ffprobe -hide_banner $IN_FILE 2>&1 | grep fps | sed 's/ fps.*//;s/.* //');
    IFS=', ' read WIDTH HEIGHT <<< $(ffprobe -hide_banner -v fatal -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$IN_FILE" 2>&1)
    echo "$IN_FILE: ${WIDTH}x${HEIGHT} @ $FPS fps"

    echo Extracting...
    FILENAME=$(echo $IN_FILE | sed 's/\..*//')
    #ffmpeg $FFMPEG_FLAGS -i "../${IN_FILE}" o_%03d.png
    #convert "../${IN_FILE}" -coalesce "o_%03d.png"
    #../../../apng_extract.py "${PWD}/${IN_FILE}"
    apngdis "${IN_FILE}" "o_"

    #rm o_1*
    #rm o_2*
    #rm o_3*

    echo Resizing...
    LONGEST=$WIDTH
    [[ $HEIGHT -gt $LONGEST ]] && LONGEST=$HEIGHT

    LONGEST_PADDED=$LONGEST

    PAD_WIDTH=$(echo "($LONGEST_PADDED-$WIDTH)/2" | bc)
    PAD_HEIGHT=$(echo "($LONGEST_PADDED-$HEIGHT)/2" | bc)
    echo "- Resize: (${PAD_WIDTH})x(${PAD_HEIGHT})"

    for ORIG in $(ls o_*.png); do
        FRAME=$(echo $ORIG | sed 's/o_//')
        ffmpeg -v error -i "o_$FRAME" -vf "scale=${LONGEST_PADDED}x${LONGEST_PADDED}:force_original_aspect_ratio=decrease,format=rgba,pad=${LONGEST_PADDED}:${LONGEST_PADDED}:-${PAD_WIDTH}:-${PAD_HEIGHT}:color=#00000000" "e_$FRAME"
    done

    rm -f o_*.{png,txt}

    #echo Optimizing...
    #for f in $(ls e_*.png); do
    #    optipng -np -nc "$f"
    #done

    #read c

    echo Combining...
    FRAME_COUNT=$(ls -l e_*.png | wc -l)
    DECIMAL=$(python3 -c "print(len(\"${FRAME_COUNT}\".strip()))")
    if [[ $DECIMAL == "1" ]]; then
        FORMAT_STR="e_%d.png"
    else
        FORMAT_STR="e_%0${DECIMAL}d.png"
    fi
        FORMAT_STR="e_%02d.png"
    ffmpeg $FFMPEG_FLAGS -r $FPS -start_number 1 -i "$FORMAT_STR" -f apng -plays 0 "output/$IN_FILE"

    rm e_*.png

    echo "Done!"
    echo
done
