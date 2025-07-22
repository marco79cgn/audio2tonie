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
  -s, --source SOURCE            Specify the source file or directory. Can be a single file, a directory, a .lst file, or a YouTube URL.
  -r, --recursive                Process directories recursively. Only applicable when the source is a directory.
  -o, --output OUTPUT_FILE       Specify the output file name. If not provided, the output file will be named based on the input file.
  -u, --upload URI               Upload the generated TAF file to a Teddycloud server. Provide the full URI (e.g., http://192.168.1.100 or https://teddycloud.local).
  -p, --path PATH                Specify the target path in the Teddycloud library where the TAF file should be uploaded. Default is the root library folder.
-c, --cookie COOKIE_FILE_PATH  Specify the path to a cookies.txt file for YouTube downloads. 
  -h, --help                     Display this help message and exit.

Examples:
  $0 -s /path/to/audio.mp3 -o /path/to/output.taf
  $0 -s /path/to/audio_folder -r -u https://teddycloud.local
  $0 -s https://www.youtube.com/watch?v=example -u https://teddycloud.local
  $0 -s https://www.youtube.com/playlist?list=example -u https://teddycloud.local
EOF
    exit 0
}

# Function to print script settings
print_settings() {
    echo "Input: ${SOURCE:-}"
    echo "Output: ${OUTPUT_FILE:-Undefined (auto mode)}"
    echo "Recursive: ${RECURSIVE:-No}"
    echo "Teddycloud URI: ${TEDDYCLOUD_URI:-Undefined (no upload)}"
    echo "Teddycloud Path: ${TEDDYCLOUD_PATH:-/}"
    echo "Cookie File Path: ${COOKIE_FILE_PATH:-Undefined (no cookies)}"
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
        local show_title
        show_title=$(echo "$episode_details_cleaned" | jq -r '.data.item.programSet.title')
        local title_cleaned
        title_cleaned=$(echo "$show_title - $title" | sed 's/[^a-zA-Z0-9äöüÄÖÜß ()._-]/_/g')
        OUTPUT_FILE="/data/${title_cleaned}.taf"
        echo "Chosen Episode: $title"
        echo -n "Downloading source file..."
        ffmpeg -loglevel quiet -stats -i "$download_url" -ac 2 -c:a libopus -b:a 96k "/data/$title_cleaned.opus" || { echo "Failed to download file"; exit 1; }
        echo " Done."
        SOURCE="/data/$title_cleaned.opus"
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
    local path="${3:-/}"  # Default to root path if not specified

    echo -n "Uploading file to Teddycloud ($uri) at path '$path'..."

    # Use curl with -L to follow redirects (e.g., HTTP to HTTPS)
    response_code=$(curl -s -o /dev/null -w "%{http_code}" -L -F "file=@$file" "${uri}/api/fileUpload?path=${path}&special=library") || {
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

# Function to download YouTube audio as MP3
download_youtube_audio() {
    local url="$1"
    local output_dir="$2"
    
    echo "Downloading YouTube audio: $url"
    
    # Download the highest quality audio as MP3
    yt-dlp -x ${YT_DLP_COOKIES_OPTION} --parse-metadata "%(thumbnail)s:%(meta_thumbnail_url)s" --embed-thumbnail --add-metadata --audio-format mp3 --audio-quality 0 -o "$output_dir/%(title)s.%(ext)s" "$url"
}

# Function to handle YouTube playlists
handle_youtube_playlist() {
    local url="$1"
    local output_dir="$2"
    
    # Send progress messages to stderr
    echo "Processing YouTube playlist: $url" >&2
    
    # Extract the playlist title
    PLAYLIST_TITLE=$(yt-dlp --flat-playlist --print "%(playlist_title)s" "$url" ${YT_DLP_COOKIES_OPTION} | head -n 1)
    if [[ -z "$PLAYLIST_TITLE" ]]; then
        echo "Error: Failed to extract playlist title." >&2
        exit 1
    fi
    # Sanitize the playlist title for use as a filename
    PLAYLIST_TITLE_SANITIZED=$(echo "$PLAYLIST_TITLE" | tr -cd '[:alnum:]._-' | tr ' ' '_')

    # Create .lst file with playlist name as metadata
    LST_FILE="${output_dir}/${PLAYLIST_TITLE_SANITIZED}.lst"
    echo "#PLAYLIST_NAME=${PLAYLIST_TITLE}" > "$LST_FILE"  # Add playlist name
    
    # Download all videos in the playlist as MP3
    echo "Downloading playlist to: $output_dir" >&2
    echo "with cookies" >&2
    yt-dlp -x --audio-format mp3 --audio-quality 0 --parse-metadata "%(thumbnail)s:%(meta_thumbnail_url)s" --embed-thumbnail --add-metadata -o "$output_dir/%(playlist_index)s - %(title).100s.%(ext)s" --yes-playlist "$url" ${YT_DLP_COOKIES_OPTION} >&2
    
    # Verify that files were downloaded
    if [[ $(find "$output_dir" -type f -name "*.mp3" | wc -l) -eq 0 ]]; then
        echo "Error: No MP3 files were downloaded." >&2
        exit 1
    fi
    
    # Create a .lst file with the correct order of the playlist entries
    find "$output_dir" -type f -name "*.mp3" | sort -V >> "$LST_FILE"
    
    echo "Created .lst file: $LST_FILE" >&2
    
    # Return only the .lst file path
    echo "$LST_FILE"
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
    elif [[ "$SOURCE" == *"www.youtube.com"* || "$SOURCE" == *"youtu.be"* ]]; then
        # Handle YouTube URLs
        TEMP_DIR=$(mktemp -d)
        echo "Created temporary directory: $TEMP_DIR"

        if [[ -n "${COOKIE_FILE_PATH:-}" ]]; then
            echo "Using cookies from: $COOKIE_FILE_PATH"
            YT_DLP_COOKIES_OPTION="--cookies $COOKIE_FILE_PATH"
        else
            YT_DLP_COOKIES_OPTION=""
        fi
        
        if [[ "$SOURCE" == *"playlist"* ]]; then
            # Handle YouTube playlist
            LST_FILE=$(handle_youtube_playlist "$SOURCE" "$TEMP_DIR")
            SOURCE="$LST_FILE"
        else
            # Handle single YouTube video
            download_youtube_audio "$SOURCE" "$TEMP_DIR"
            SOURCE=$(find "$TEMP_DIR" -type f -name "*.mp3" | head -n 1)
        fi
        
        count=$(sed -n '$=' "$SOURCE")
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

    # Transcode the files
    echo "Starting transcoding..."
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
        -p|--path) TEDDYCLOUD_PATH="$2"; shift ;;
        -c|--cookie) COOKIE_FILE_PATH="$2"; shift ;;
        -h|--help) display_help ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Run the main script logic
main