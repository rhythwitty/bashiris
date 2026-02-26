#!/bin/bash
# A Mac-friendly downloader script
URL=$1
if [ -z "$URL" ]; then
    echo "Usage: ytdl <URL>"
    return 1 2>/dev/null || exit 1
fi

yt-dlp -f "bv*[vcodec^=avc]+ba[ext=m4a]/b[ext=mp4]/b" "$URL"
