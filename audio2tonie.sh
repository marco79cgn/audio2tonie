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
elif [[ $SOURCE == *"www.ardaudiothek.de"* ]]; then
  count=1
  echo $SEPARATOR
  echo "ARD Audiothek Link detected."
  url_cleaned=${SOURCE%/}
  id=${url_cleaned##*/}
  episode_details=$(curl -s "https://api.ardaudiothek.de/graphql/items/$id")
  episode_details_cleaned=$(echo $episode_details | awk '{ printf("%s ", $0) }' | sed 's/[^ -~]//g')
  title=$(echo $episode_details_cleaned | jq -r '.data.item.title')
  if [[ -n $title ]]; then
     download_url=$(echo "$episode_details_cleaned" | jq -r '.data.item.audios[0].url')
     title_cleaned=$(echo $title | sed -e 's/[^A-Za-z0-9.-]/./g' -e 's/\.\.\././g' -e 's/\.\././g' -e 's/\.*$//')
     input_file=$(echo ${download_url##*/})
     OUTPUT_FILE="/data/${title_cleaned}.taf"
     echo "Chosen Episode: $title"
     echo -n "Downloading source file..."
     curl -s "$download_url" -o /data/$input_file
     echo " Done."
     SOURCE="/data/$input_file"
  fi
elif [[ "$SOURCE" == *.* ]]; then
    count=1
else
    if [[ $RECURSIVE ]]; then
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
    count=$(find "$SOURCE" -type f \( -name "*.mp3" -o -name "*.mp2" -o -name "*.m4a" -o -name "*.m4b" -o -name "*.opus" -o -name "*.ogg" -o -name "*.wav" -o -name "*.aac" -o -name "*.mp4" \) | wc -l)
fi

echo $SEPARATOR
echo "Start transcoding: "
if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="${SOURCE%.*}.taf"
fi
filename=$(basename "$OUTPUT_FILE")
echo "Creating $filename with $count chapter(s)..."
python3 $OPUS_2_TONIE_PATH/opus2tonie.py "$SOURCE" "$OUTPUT_FILE"
echo "Finished! Enjoy."
