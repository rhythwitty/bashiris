#!/bin/bash

# Self-Update Script
if [[ "$1" == "--update" ]]; then
    echo "Updating downloadyoutube..."
    curl -sL https://github.com/rhythwitty/bashrepo/raw/main/scripts/downloadyoutube.sh -o downloadyoutube
    chmod +x downloadyoutube
    sudo mv downloadyoutube /usr/local/bin/downloadyoutube
    echo "Update complete!"
    exit 0
fi

# A Mac-friendly downloader script
URL=$1
if [ -z "$URL" ]; then
    echo "Usage: downloadyoutube <URL>"
    return 1 2>/dev/null || exit 1
fi

yt-dlp -f "bv*[vcodec^=avc]+ba[ext=m4a]/b[ext=mp4]/b" --merge-output-format mp4 "$URL"
