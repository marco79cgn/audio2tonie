#!/bin/bash

set -euo pipefail  # Enable strict mode: exit on error, unset variables, and pipeline errors

OPUS_2_TONIE_PATH="/app"
SEPARATOR="------"

# Function to display help information
display_help() {
    cat <<EOF
Usage: $0 [options]

This script converts audio files to the Toniebox TAF format and optionally uploads them to a Teddycloud server.

Options:
  -s, --source SOURCE       Specify the source file or directory. Can be a single file, a directory, or a .lst file containing a list of files.
  -r, --recursive           Process directories recursively. Only applicable when the source is a directory.
  -o, --output OUTPUT_FILE  Specify the output file name. If not provided, the output file will be named based on the input file.
  -u, --upload URI          Upload the generated TAF file to a Teddycloud server. Provide the full URI (e.g., http://192.168.1.100 or https://teddycloud.local).
  -h, --help                Display this help message and exit.

Examples:
  $0 -s /path/to/audio.mp3 -o /path/to/output.taf
  $0 -s /path/to/audio_folder -r -u https://teddycloud.local
EOF
    exit 0
}

# Function to print script settings
print_settings() {
    echo "Input: ${SOURCE:-}"
    echo "Output: ${OUTPUT_FILE:-Undefined (auto mode)}"
    echo "Recursive: ${RECURSIVE:-No}"
    echo "Teddycloud URI: ${TEDDYCLOUD_URI:-Undefined (no upload)}"
}

# Function to download ARD Audiothek episode
download_ard_episode() {
    echo "$SEPARATOR"
    echo "ARD Audiothek Link detected."
    local url_cleaned="${SOURCE%/}"
    local id="${url_cleaned##*/}"
    local episode_details
    episode_details=$(curl -s "https://api.ardaudiothek.de/graphql/items/$id") || { echo "Failed to fetch episode details"; exit 1; }
    local episode_details_cleaned
    episode_details_cleaned=$(echo "$episode_details" | awk '{ printf("%s ", $0) }' | sed 's/[^ -~]//g')
    local title
    title=$(echo "$episode_details_cleaned" | jq -r '.data.item.title') || { echo "Failed to parse episode title"; exit 1; }
    if [[ -n "$title" ]]; then
        local download_url
        download_url=$(echo "$episode_details_cleaned" | jq -r '.data.item.audios[0].url') || { echo "Failed to parse download URL"; exit 1; }
        local title_cleaned
        title_cleaned=$(echo "$title" | sed -e 's/[^A-Za-z0-9.-]/./g' -e 's/\.\.\././g' -e 's/\.\././g' -e 's/\.*$//')
        local input_file
        input_file=$(basename "$download_url")
        OUTPUT_FILE="/data/${title_cleaned}.taf"
        echo "Chosen Episode: $title"
        echo -n "Downloading source file..."
        curl -s "$download_url" -o "/data/$input_file" || { echo "Failed to download file"; exit 1; }
        echo " Done."
        SOURCE="/data/$input_file"
    fi
}

# Function to transcode files
transcode_files() {
    local input="$1"
    local output="$2"
    local count="$3"
    echo "$SEPARATOR"
    echo "Start transcoding: "
    echo "Creating $(basename "$output") with $count chapter(s)..."
    python3 "$OPUS_2_TONIE_PATH/opus2tonie.py" "$input" "$output" || { echo "Transcoding failed"; exit 1; }
}

# Function to upload file to Teddycloud
upload_to_teddycloud() {
    local file="$1"
    local uri="$2"

    echo -n "Uploading file to Teddycloud ($uri)..."

    # Use curl with -L to follow redirects (e.g., HTTP to HTTPS)
    response_code=$(curl -s -o /dev/null -w "%{http_code}" -L -F "file=@$file" "${uri}/api/fileUpload?path=&special=library") || {
        echo "Failed to upload file."
        exit 1
    }

    if [[ "$response_code" == 200 ]]; then
        echo ": OK"
    else
        echo "Error! Upload failed with HTTP code: $response_code"
        exit 1
    fi
}

# Function to validate and normalize the Teddycloud URI
normalize_teddycloud_uri() {
    local uri="$1"

    # Ensure the URI starts with http:// or https://
    if [[ ! "$uri" =~ ^https?:// ]]; then
        echo "Error: Teddycloud URI must start with http:// or https://"
        exit 1
    fi

    # Remove trailing slashes
    uri="${uri%/}"

    echo "$uri"
}

# Function to print TAF file creation details
print_taf_creation_details() {
    local input="$1"
    local output="$2"
    local count="$3"

    echo "$SEPARATOR"
    echo "Creating TAF file:"
    echo "  - Input: $input"
    echo "  - Output: $output"
    echo "  - Number of chapters: $count"
}

# Function to check if a directory contains valid audio files
has_valid_audio_files() {
    local dir="$1"
    local count
    count=$(find "$dir" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.mp2" -o -name "*.m4a" -o -name "*.m4b" -o -name "*.opus" -o -name "*.ogg" -o -name "*.wav" -o -name "*.aac" -o -name "*.mp4" \) | wc -l)
    [[ "$count" -gt 0 ]]
}

# Function to get the base name of a directory (without trailing slash)
get_basename() {
    local path="$1"
    path="${path%/}"  # Remove trailing slash
    basename "$path"
}

# Function to process directories recursively
process_recursive() {
    for d in "$SOURCE"/*/; do
        local dirname
        dirname=$(basename "$d")
        OUTPUT_FILE="${dirname}.taf"
        echo "Current folder: $dirname"
        local count
        local count
        count=$(find "$d" -maxdepth 1 -type f | wc -l)
        transcode_files "$d" "$SOURCE/$OUTPUT_FILE" "$count"
        if [[ -n "${TEDDYCLOUD_IP:-}" ]]; then
            upload_to_teddycloud "$SOURCE/$OUTPUT_FILE"
        fi
        echo "$SEPARATOR"
    done
    echo "Finished! Enjoy."
    exit 0
}

# Main script logic
main() {
    echo "$SEPARATOR"
    print_settings

    if [[ "$SOURCE" == *.lst ]]; then
        count=$(sed -n '$=' "$SOURCE")
    elif [[ "$SOURCE" == *"www.ardaudiothek.de"* ]]; then
        download_ard_episode
        count=1
    elif [[ "$SOURCE" == *.* ]]; then
        count=1
    else
        if [[ -n "${RECURSIVE:-}" ]]; then
            process_recursive
        fi

        # Check if the directory contains valid audio files
        if ! has_valid_audio_files "$SOURCE"; then
            echo "Error: No valid audio files found in the directory: $SOURCE"
            exit 1
        fi

        count=$(find "$SOURCE" -type f \( -name "*.mp3" -o -name "*.mp2" -o -name "*.m4a" -o -name "*.m4b" -o -name "*.opus" -o -name "*.ogg" -o -name "*.wav" -o -name "*.aac" -o -name "*.mp4" \) | wc -l)
    fi

    if [[ -z "${OUTPUT_FILE:-}" ]]; then
        # Use the folder name as the base name for the .taf file
        SOURCE="${SOURCE%/}"  # Remove trailing slash
        OUTPUT_FILE="${SOURCE}.taf"
    fi

    # Print TAF file creation details
    print_taf_creation_details "$SOURCE" "$OUTPUT_FILE" "$count"

    transcode_files "$SOURCE" "$OUTPUT_FILE" "$count"

    if [[ -n "${TEDDYCLOUD_URI:-}" ]]; then
        normalized_uri=$(normalize_teddycloud_uri "$TEDDYCLOUD_URI")
        upload_to_teddycloud "$OUTPUT_FILE" "$normalized_uri"
    fi

    echo "Finished! Enjoy."
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -s|--source) SOURCE="$2"; shift ;;
        -r|--recursive) RECURSIVE=1 ;;
        -o|--output) OUTPUT_FILE="$2"; shift ;;
        -u|--upload) TEDDYCLOUD_URI="$2"; shift ;;
        -h|--help) display_help ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Validate required arguments
if [[ -z "${SOURCE:-}" ]]; then
    echo "Error: --source is required."
    display_help
fi

# Run the main script logic
main