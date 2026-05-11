#!/bin/bash

# ─────────────────────────────────────────────
#  download-yt — yt-dlp wrapper
#  https://github.com/rhythwitty/bashiris
# ─────────────────────────────────────────────
# IRIS_DESC: Download YouTube videos via yt-dlp

SCRIPT_NAME="download-yt"

# ── Defaults ──────────────────────────────────
DEFAULT_BROWSER="chrome"
DEFAULT_MAX_RES="1080"

# ── Help ──────────────────────────────────────
show_help() {
    cat << EOF

$(tput bold)USAGE$(tput sgr0)
    $SCRIPT_NAME [OPTIONS] <URL>
    $SCRIPT_NAME --update-deps

$(tput bold)DESCRIPTION$(tput sgr0)
    Downloads YouTube videos via yt-dlp using browser cookies for authenticated downloads.
    The browser must be installed and have visited the URL's site so yt-dlp can read
    its session cookies for age-gated / members-only videos.
    Output is always saved as MP4 (H.264 + AAC).
    Use --update-deps to refresh yt-dlp when YouTube changes its player and format logic.

$(tput bold)OPTIONS$(tput sgr0)
    -b, --browser <browser>     Browser to pull cookies from for authenticated downloads
                                Supported: chrome, firefox, safari, edge, brave, opera
                                Default: $DEFAULT_BROWSER

    -r, --resolution <res>      Maximum video resolution to download
                                Choices: 480, 720, 1080
                                Default: ${DEFAULT_MAX_RES}p

    -p, --playlist              Allow downloading entire playlists if URL points to one
    -h, --help                  Show this help message

    --update-deps               Update yt-dlp to the latest version (fixes format errors)

$(tput bold)EXAMPLES$(tput sgr0)
    $SCRIPT_NAME 'https://youtube.com/watch?v=...'
    $SCRIPT_NAME -b firefox 'https://youtube.com/watch?v=...'
    $SCRIPT_NAME -r 720 'https://youtube.com/watch?v=...'
    $SCRIPT_NAME -p 'https://youtube.com/playlist?list=...'
    $SCRIPT_NAME -b safari -r 480 'https://youtube.com/watch?v=...'

$(tput bold)TROUBLESHOOTING$(tput sgr0)
    "Requested format is not available" / "n challenge solving failed"
    → Run: $SCRIPT_NAME --update-deps

    "zsh: no matches found" / URL gets split at & or ?
    → Always quote URLs: $SCRIPT_NAME 'https://youtube.com/watch?v=...&t=7s'

EOF
}

# ── Update Dependencies ──────────────────────────
if [[ "$1" == "--update-deps" ]]; then
    echo "Updating yt-dlp..."
    if command -v brew &> /dev/null && brew list yt-dlp &> /dev/null; then
        brew upgrade yt-dlp
    elif command -v pip3 &> /dev/null && pip3 show yt-dlp &> /dev/null; then
        pip3 install --upgrade yt-dlp
    elif command -v yt-dlp &> /dev/null; then
        yt-dlp -U
    else
        echo "❌  yt-dlp not found. Install it with: brew install yt-dlp"
        exit 1
    fi
    echo "✅  yt-dlp update complete!"
    exit 0
fi

# ── Argument Parsing ──────────────────────────
BROWSER="$DEFAULT_BROWSER"
MAX_RES="$DEFAULT_MAX_RES"
URL=""
ALLOW_PLAYLIST=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            show_help
            exit 0
            ;;
        -b | --browser)
            BROWSER="$2"
            shift 2
            ;;
        -r | --resolution)
            MAX_RES="$2"
            shift 2
            ;;
        -p | --playlist)
            ALLOW_PLAYLIST=true
            shift
            ;;
        -*)
            echo "❌  Unknown option: $1"
            echo "    Run '$SCRIPT_NAME --help' for usage."
            exit 1
            ;;
        *)
            URL="$1"
            shift
            ;;
    esac
done

# ── Validate URL ──────────────────────────────
if [[ -z "$URL" ]]; then
    echo "❌  No URL provided."
    echo "    Run '$SCRIPT_NAME --help' for usage."
    exit 1
fi

# ── Validate Resolution ───────────────────────
case "$MAX_RES" in
    480 | 720 | 1080) ;;
    *)
        echo "❌  Invalid resolution: ${MAX_RES}. Choose from 480, 720, or 1080."
        exit 1
        ;;
esac

# ── Validate Browser ──────────────────────────
case "$BROWSER" in
    chrome | firefox | safari | edge | brave | opera) ;;
    *)
        echo "❌  Unsupported browser: $BROWSER"
        echo "    Supported: chrome, firefox, safari, edge, brave, opera"
        exit 1
        ;;
esac

# ── Check Dependencies ───────────────────────
if ! command -v yt-dlp &> /dev/null; then
    echo "❌  yt-dlp is not installed."
    echo "    Install it with: brew install yt-dlp"
    exit 1
fi

# ── Build Format String ───────────────────────
# Prefer H.264 video up to MAX_RES + M4A audio, fallback to best mp4
FORMAT="bv*[vcodec^=avc][height<=${MAX_RES}]+ba[ext=m4a]/b[ext=mp4][height<=${MAX_RES}]/b[ext=mp4]/b"

# ── Download ──────────────────────────────────
# If playlist is disabled, strip playlist-related parameters from YouTube URLs
# to avoid 429 errors when yt-dlp attempts to extract playlist metadata.
if [ "$ALLOW_PLAYLIST" = false ]; then
    if [[ "$URL" == *"youtube.com"* ]] || [[ "$URL" == *"youtu.be"* ]]; then
        # Strip list and index parameters
        CLEANED_URL=$(echo "$URL" | sed -e 's/[&?]list=[^&]*//g' -e 's/[&?]index=[^&]*//g')
        # Fix potential malformed URL if the first parameter was removed
        if [[ "$CLEANED_URL" == *"watch&"* ]]; then
            CLEANED_URL="${CLEANED_URL/watch&/watch?}"
        fi
        URL="$CLEANED_URL"
    fi
fi

echo "⬇️   Downloading:  $URL"
echo "🌐  Browser:       $BROWSER"
echo "📐  Max res:       ${MAX_RES}p"

if [ "$ALLOW_PLAYLIST" = true ]; then
    echo "📜  Playlist:      enabled"
else
    echo "📜  Playlist:      disabled (single video)"
fi
echo ""

PLAYLIST_FLAG="--no-playlist"
if [ "$ALLOW_PLAYLIST" = true ]; then
    PLAYLIST_FLAG="--yes-playlist"
fi

yt-dlp \
    --cookies-from-browser "$BROWSER" \
    -f "$FORMAT" \
    --merge-output-format mp4 \
    --extractor-args "youtubetab:skip=authcheck" \
    $PLAYLIST_FLAG \
    "$URL"
