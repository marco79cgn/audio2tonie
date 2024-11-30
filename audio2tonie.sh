#!/bin/bash

OPUS_2_TONIE_PATH=/app
SEPARATOR='------'
echo $SEPARATOR

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -s|--source) SOURCE="$2"; shift ;;
        -r|--recursive) RECURSIVE=1 ;;
        -o|--output) OUTPUT_FILE="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

echo "Input: $SOURCE"
echo -n "Output: "
if [ "$OUTPUT_FILE" ]; then echo "$OUTPUT_FILE"; else echo "Undefined (auto mode)"; fi
echo -n "Recursive: "
if [ "$RECURSIVE" ]; then echo "Yes"; else echo "No"; fi

if [[ $SOURCE == *.lst ]]; then
    count=$(sed -n '$=' "$SOURCE")
elif [[ "$SOURCE" == *.* ]]; then
    count=1
else
    if [[ $RECURSIVE ]]; then
      echo "Transcoding recursive, ignoring output-filename"
      echo $SEPARATOR
      for d in $SOURCE/*/ ; do
          DIRNAME=$(basename "$d")
          OUTPUT_FILE="${DIRNAME}.taf"
          echo "Current folder: $DIRNAME"
          count=$(ls "$d" | wc -l)
          echo "Start transcoding: "
          echo "${OUTPUT_FILE}..."
          python3 $OPUS_2_TONIE_PATH/opus2tonie.py "$d" "$SOURCE/$OUTPUT_FILE"
          echo "Created $OUTPUT_FILE with $count chapter(s)."
          echo $SEPARATOR
      done
      echo "Finished! Enjoy."
      exit 0
    fi
    count=0
    for i in `find $SOURCE -type f -maxdepth 1 -name \*.mp3 -or -name "*.mp2" -or -name "*.m4a" -or -name "*.m4b" -or -name "*.opus" -or -name "*.ogg" -or -name "*.wav" -or -name "*.aac" -or -name "*.mp4"`;
    do
      (( count++ ))
    done
fi

echo $SEPARATOR
echo "Start transcoding: "
if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="${SOURCE%.*}.taf"
fi
python3 $OPUS_2_TONIE_PATH/opus2tonie.py "$SOURCE" "$OUTPUT_FILE"
filename=$(basename "$OUTPUT_FILE")
echo "Created $filename with $count chapter(s)."
echo "Finished! Enjoy."