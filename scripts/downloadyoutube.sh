#!/bin/bash

# ─────────────────────────────────────────────
#  downloadyoutube — yt-dlp wrapper
#  https://github.com/rhythwitty/bashrepo
# ─────────────────────────────────────────────

SCRIPT_NAME="downloadyoutube"
SCRIPT_URL="https://github.com/rhythwitty/bashrepo/raw/main/scripts/downloadyoutube.sh"

# ── Defaults ──────────────────────────────────
DEFAULT_BROWSER="chrome"
DEFAULT_MAX_RES="1080"

# ── Help ──────────────────────────────────────
show_help() {
    cat <<EOF

$(tput bold)USAGE$(tput sgr0)
    $SCRIPT_NAME [OPTIONS] <URL>
    $SCRIPT_NAME --update <self|ytdlp>

$(tput bold)OPTIONS$(tput sgr0)
    -b, --browser <browser>     Browser to pull cookies from for authenticated downloads
                                Supported: chrome, firefox, safari, edge, brave, opera
                                Default: $DEFAULT_BROWSER

    -r, --resolution <res>      Maximum video resolution to download
                                Choices: 480, 720, 1080
                                Default: ${DEFAULT_MAX_RES}p

    -h, --help                  Show this help message

    --update self               Update this script to the latest version
    --update ytdlp              Update yt-dlp to the latest version (fixes format errors)

$(tput bold)EXAMPLES$(tput sgr0)
    $SCRIPT_NAME https://youtube.com/watch?v=...
    $SCRIPT_NAME -b firefox https://youtube.com/watch?v=...
    $SCRIPT_NAME -r 720 https://youtube.com/watch?v=...
    $SCRIPT_NAME -b safari -r 480 https://youtube.com/watch?v=...

$(tput bold)TROUBLESHOOTING$(tput sgr0)
    "Requested format is not available" / "n challenge solving failed"
    → Run: $SCRIPT_NAME --update ytdlp
      YouTube frequently changes its player; keeping yt-dlp up to date fixes this.

$(tput bold)NOTES$(tput sgr0)
    • The browser you specify must be installed and have visited the URL's site
      so yt-dlp can read its session cookies (handles age-gated / members-only videos).
    • Output is always saved as MP4 (H.264 + AAC).

EOF
}

# ── Update ────────────────────────────────────
if [[ "$1" == "--update" ]]; then
    case "$2" in
        self)
            echo "Updating $SCRIPT_NAME..."
            curl -sL "$SCRIPT_URL" -o "$SCRIPT_NAME"
            chmod +x "$SCRIPT_NAME"
            sudo mv "$SCRIPT_NAME" /usr/local/bin/"$SCRIPT_NAME"
            echo "✅  Script update complete!"
            ;;
        ytdlp)
            echo "Updating yt-dlp..."
            if command -v brew &>/dev/null && brew list yt-dlp &>/dev/null 2>&1; then
                brew upgrade yt-dlp
            elif command -v pip3 &>/dev/null && pip3 show yt-dlp &>/dev/null 2>&1; then
                pip3 install --upgrade yt-dlp
            elif command -v yt-dlp &>/dev/null; then
                yt-dlp -U
            else
                echo "❌  yt-dlp not found. Install it with: brew install yt-dlp"
                exit 1
            fi
            echo "✅  yt-dlp update complete!"
            ;;
        *)
            echo "❌  Missing or invalid target for --update."
            echo ""
            echo "    Usage:  $SCRIPT_NAME --update <target>"
            echo ""
            echo "    Targets:"
            echo "      self    — update this script"
            echo "      ytdlp   — update yt-dlp (fixes format/n-challenge errors)"
            exit 1
            ;;
    esac
    exit 0
fi

# ── Argument Parsing ──────────────────────────
BROWSER="$DEFAULT_BROWSER"
MAX_RES="$DEFAULT_MAX_RES"
URL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -b|--browser)
            BROWSER="$2"
            shift 2
            ;;
        -r|--resolution)
            MAX_RES="$2"
            shift 2
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
    480|720|1080) ;;
    *)
        echo "❌  Invalid resolution: ${MAX_RES}. Choose from 480, 720, or 1080."
        exit 1
        ;;
esac

# ── Validate Browser ──────────────────────────
case "$BROWSER" in
    chrome|firefox|safari|edge|brave|opera) ;;
    *)
        echo "❌  Unsupported browser: $BROWSER"
        echo "    Supported: chrome, firefox, safari, edge, brave, opera"
        exit 1
        ;;
esac

# ── Build Format String ───────────────────────
# Prefer H.264 video up to MAX_RES + M4A audio, fallback to best mp4
FORMAT="bv*[vcodec^=avc][height<=${MAX_RES}]+ba[ext=m4a]/b[ext=mp4][height<=${MAX_RES}]/b[ext=mp4]/b"

# ── Download ──────────────────────────────────
echo "⬇️   Downloading:  $URL"
echo "🌐  Browser:       $BROWSER"
echo "📐  Max res:       ${MAX_RES}p"
echo ""

yt-dlp \
    --cookies-from-browser "$BROWSER" \
    -f "$FORMAT" \
    --merge-output-format mp4 \
    "$URL"
