#!/bin/bash

OPUS_2_TONIE_PATH=/app
SEPARATOR='------'

# Function to display help information
display_help() {
    echo "Usage: $0 [options]"
    echo
    echo "This script converts audio files to the Toniebox TAF format and optionally uploads them to a Teddycloud server."
    echo
    echo "Options:"
    echo "  -s, --source SOURCE       Specify the source file or directory. Can be a single file, a directory, or a .lst file containing a list of files."
    echo "  -r, --recursive           Process directories recursively. Only applicable when the source is a directory."
    echo "  -o, --output OUTPUT_FILE  Specify the output file name. If not provided, the output file will be named based on the input file."
    echo "  -u, --upload TEDDYCLOUD_IP Upload the generated TAF file to a Teddycloud server. Provide the IP address of the Teddycloud server."
    echo "  -h, --help                Display this help message and exit."
    echo
    echo "Examples:"
    echo "  $0 -s /path/to/audio.mp3 -o /path/to/output.taf"
    echo "  $0 -s /path/to/audio_folder -r -u 192.168.1.100"
    echo
    exit 0
}

# Function to print script settings
print_settings() {
    echo "Input: $SOURCE"
    echo -n "Output: "
    if [ "$OUTPUT_FILE" ]; then echo "$OUTPUT_FILE"; else echo "Undefined (auto mode)"; fi
    echo -n "Recursive: "
    if [ "$RECURSIVE" ]; then echo "Yes"; else echo "No"; fi
    echo -n "Teddycloud IP: "
    if [ "$TEDDYCLOUD_IP" ]; then echo "$TEDDYCLOUD_IP"; else echo "Undefined (no upload)"; fi
}

# Function to download ARD Audiothek episode
download_ard_episode() {
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
}

# Function to transcode files
transcode_files() {
    local input=$1
    local output=$2
    local count=$3
    echo $SEPARATOR
    echo "Start transcoding: "
    echo "Creating $(basename "$output") with $count chapter(s)..."
    python3 $OPUS_2_TONIE_PATH/opus2tonie.py "$input" "$output"
}

# Function to upload file to Teddycloud
upload_to_teddycloud() {
    local file=$1
    echo -n "Uploading file to Teddycloud..."
    response_code=$(curl -s -o /dev/null -F "file=@$file" -w "%{http_code}" "http://$TEDDYCLOUD_IP/api/fileUpload?path=&special=library")
    if [ "${response_code}" != 200 ]; then
        echo "Error! Upload didn't succeed."
    else
        echo ": OK"
    fi
}

# Function to process directories recursively
process_recursive() {
    for d in $SOURCE/*/ ; do
        DIRNAME=$(basename "$d")
        OUTPUT_FILE="${DIRNAME}.taf"
        echo "Current folder: $DIRNAME"
        count=$(ls "$d" | wc -l)
        transcode_files "$d" "$SOURCE/$OUTPUT_FILE" "$count"
        if [ "$TEDDYCLOUD_IP" ]; then
            upload_to_teddycloud "$SOURCE/$OUTPUT_FILE"
        fi
        echo $SEPARATOR
    done
    echo "Finished! Enjoy."
    exit 0
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -s|--source) SOURCE="$2"; shift ;;
        -r|--recursive) RECURSIVE=1 ;;
        -o|--output) OUTPUT_FILE="$2"; shift ;;
        -u|--upload) TEDDYCLOUD_IP="$2"; shift ;;
        -h|--help) display_help ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

echo $SEPARATOR
print_settings

if [[ $SOURCE == *.lst ]]; then
    count=$(sed -n '$=' "$SOURCE")
elif [[ $SOURCE == *"www.ardaudiothek.de"* ]]; then
    download_ard_episode
    count=1
elif [[ "$SOURCE" == *.* ]]; then
    count=1
else
    if [[ $RECURSIVE ]]; then
        process_recursive
    fi
    count=$(find "$SOURCE" -type f \( -name "*.mp3" -o -name "*.mp2" -o -name "*.m4a" -o -name "*.m4b" -o -name "*.opus" -o -name "*.ogg" -o -name "*.wav" -o -name "*.aac" -o -name "*.mp4" \) | wc -l)
fi

if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="${SOURCE%.*}.taf"
fi

transcode_files "$SOURCE" "$OUTPUT_FILE" "$count"

if [ "$TEDDYCLOUD_IP" ]; then
    upload_to_teddycloud "$OUTPUT_FILE"
fi

echo "Finished! Enjoy."