#!/bin/bash

OPUS_2_TONIE_PATH=/app
SEPARATOR='------'
echo $SEPARATOR

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -s|--source) SOURCE="$2"; shift ;;
        -r|--recursive) RECURSIVE=1 ;;
        -o|--output) OUTPUT_FILE="$2"; shift ;;
        -u|--upload) TEDDYCLOUD_IP="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

echo "Input: $SOURCE"
echo -n "Output: "
if [ "$OUTPUT_FILE" ]; then echo "$OUTPUT_FILE"; else echo "Undefined (auto mode)"; fi
echo -n "Recursive: "
if [ "$RECURSIVE" ]; then echo "Yes"; else echo "No"; fi
echo -n "Teddycloud IP: "
if [ "$TEDDYCLOUD_IP" ]; then echo "$TEDDYCLOUD_IP"; else echo "Undefined (no upload)"; fi

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
     show_title=$(echo "$episode_details_cleaned" | jq -r '.data.item.programSet.title')
     title_cleaned=$(echo "$show_title - $title" | sed 's/[^a-zA-Z0-9äöüÄÖÜß ()._-]/_/g')
     input_file=$(echo ${download_url##*/})
     OUTPUT_FILE="/data/${title_cleaned}.taf"
     echo "Chosen Episode: $title"
     echo -n "Downloading source file..."
     ffmpeg -loglevel quiet -stats -i "$download_url" -ac 2 -c:a libopus -b:a 96k "/data/$title_cleaned.opus"
     echo " Done."
     SOURCE="/data/$title_cleaned.opus"
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
          if [ "$TEDDYCLOUD_IP" ]; then
            echo -n "Uploading file to Teddycloud..."
            response_code=$(curl -s -o /dev/null -F "file=@$SOURCE/$OUTPUT_FILE" -w "%{http_code}" "http://$TEDDYCLOUD_IP/api/fileUpload?path=&special=library")
            if [ "${response_code}" != 200 ]; then
              echo "Error trying to upload to Teddycloud."
            else
              echo ": OK"
            fi
          fi
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
if [ "$TEDDYCLOUD_IP" ]; then
  echo -n "Uploading file to Teddycloud..."
  response_code=$(curl -s -o /dev/null -F "file=@$OUTPUT_FILE" -w "%{http_code}" "http://$TEDDYCLOUD_IP/api/fileUpload?path=&special=library")
  if [ "${response_code}" != 200 ]; then
    echo "Error! Upload didn't succeed."
  else
    echo ": OK"
  fi
fi
echo "Finished! Enjoy."
