#!/bin/bash

# ─────────────────────────────────────────────
#  download-yt — yt-dlp wrapper
#  https://github.com/rhythwitty/bashiris
# ─────────────────────────────────────────────
# IRIS_DESC: Download YouTube videos via yt-dlp

IRIS_SCRIPT_NAME="download-yt"

# ── Load shared library ───────────────────────────────────────────────────────
_COMMON="$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
[[ -f "$_COMMON" ]] || _COMMON="${IRIS_LIB_DIR:-/usr/local/lib/iris}/lib/common.sh"
# shellcheck source=scripts/lib/common.sh
source "$_COMMON" || {
    echo "⊘  Could not load iris common lib" >&2
    exit 1
}

# ── Defaults ──────────────────────────────────────────────────────────────────
DEFAULT_BROWSER="chrome"
DEFAULT_MAX_RES="1080"
BROWSER="$DEFAULT_BROWSER"
MAX_RES="$DEFAULT_MAX_RES"
URL=""
ALLOW_PLAYLIST=false

# ── Help ──────────────────────────────────────────────────────────────────────
show_help() {
    render_help_banner "download-yt" "download-yt — help & usage"

    render_help_section "USAGE"
    echo "    download-yt ${DIM}[OPTIONS]${RESET} ${BOLD}<URL>${RESET}"
    echo "    download-yt --update-deps"
    echo ""

    render_help_section "DESCRIPTION"
    echo "    ${DIM}Downloads YouTube videos via yt-dlp using browser cookies for"
    echo "    authenticated (age-gated / members-only) downloads."
    echo "    Output is always saved as MP4 (H.264 + AAC)."
    echo "    Use --update-deps to refresh yt-dlp when YouTube changes its player.${RESET}"
    echo ""

    render_help_section "OPTIONS"
    render_help_option "-b, --browser <browser>" "Browser for cookies ${DIM}(default: ${DEFAULT_BROWSER})${RESET}"
    render_help_option "" "                        ${DIM}Supported: chrome, firefox, safari, edge, brave, opera${RESET}"
    render_help_option "-r, --resolution <res>" "Max video resolution ${DIM}(default: ${DEFAULT_MAX_RES}p)${RESET}"
    render_help_option "" "                        ${DIM}Choices: 480, 720, 1080${RESET}"
    render_help_option "-p, --playlist" "Allow entire playlist download"
    render_help_option "-h, --help" "Show this help message"
    render_help_option "--update-deps" "Update yt-dlp to the latest version"
    echo ""

    render_help_section "EXAMPLES"
    echo "    ${DIM}download-yt 'https://youtube.com/watch?v=...'${RESET}"
    echo "    ${DIM}download-yt -b firefox 'https://youtube.com/watch?v=...'${RESET}"
    echo "    ${DIM}download-yt -r 720 'https://youtube.com/watch?v=...'${RESET}"
    echo "    ${DIM}download-yt -p 'https://youtube.com/playlist?list=...'${RESET}"
    echo "    ${DIM}download-yt -b safari -r 480 'https://youtube.com/watch?v=...'${RESET}"
    echo ""

    render_help_section "TROUBLESHOOTING"
    echo "    ${DIM}\"Requested format is not available\" / \"n challenge solving failed\"${RESET}"
    echo "    ${CYAN}→${RESET} Run: ${BOLD}download-yt --update-deps${RESET}"
    echo ""
    echo "    ${DIM}\"zsh: no matches found\" / URL split at & or ?${RESET}"
    echo "    ${CYAN}→${RESET} Always quote URLs: ${BOLD}download-yt 'https://youtube.com/watch?v=...&t=7s'${RESET}"
    echo ""
}

# ── Update Dependencies ───────────────────────────────────────────────────────
if [[ "$1" == "--update-deps" ]]; then
    log_step "Updating yt-dlp…"
    if command -v brew &> /dev/null && brew list yt-dlp &> /dev/null; then
        brew upgrade yt-dlp
    elif command -v pip3 &> /dev/null && pip3 show yt-dlp &> /dev/null; then
        pip3 install --upgrade yt-dlp
    elif command -v yt-dlp &> /dev/null; then
        yt-dlp -U
    else
        log_err "yt-dlp not found."
        log_detail "Install it with: ${BOLD}brew install yt-dlp${RESET}" >&2
        exit "$IRIS_EXIT_FAIL"
    fi
    log_success "yt-dlp update complete."
    exit "$IRIS_EXIT_OK"
fi

# ── Argument Parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            show_help
            exit 0
            ;;
        -b | --browser)
            BROWSER="$(parse_flag_value --browser "$2")"
            shift 2
            ;;
        -r | --resolution)
            MAX_RES="$(parse_flag_value --resolution "$2")"
            shift 2
            ;;
        -p | --playlist)
            ALLOW_PLAYLIST=true
            shift
            ;;
        -*)
            unknown_option "$1"
            ;;
        *)
            URL="$1"
            shift
            ;;
    esac
done

# ── Validation ────────────────────────────────────────────────────────────────
if [[ -z "$URL" ]]; then
    log_err "No URL provided."
    log_detail "Run '${BOLD}download-yt --help${RESET}' for usage." >&2
    exit "$IRIS_EXIT_USAGE"
fi

case "$MAX_RES" in
    480 | 720 | 1080) ;;
    *)
        log_err "Invalid resolution: ${BOLD}${MAX_RES}${RESET}. Choose from 480, 720, or 1080."
        exit "$IRIS_EXIT_USAGE"
        ;;
esac

case "$BROWSER" in
    chrome | firefox | safari | edge | brave | opera) ;;
    *)
        log_err "Unsupported browser: ${BOLD}${BROWSER}${RESET}."
        log_detail "Supported: chrome, firefox, safari, edge, brave, opera" >&2
        exit "$IRIS_EXIT_USAGE"
        ;;
esac

require_command yt-dlp "Install with: brew install yt-dlp  •  or run: download-yt --update-deps"

# ── Build Format String ───────────────────────────────────────────────────────
FORMAT="bv*[vcodec^=avc][height<=${MAX_RES}]+ba[ext=m4a]/b[ext=mp4][height<=${MAX_RES}]/b[ext=mp4]/b"

# ── Strip Playlist Params (when playlist disabled) ────────────────────────────
if [[ "$ALLOW_PLAYLIST" == false ]]; then
    if [[ "$URL" == *"youtube.com"* ]] || [[ "$URL" == *"youtu.be"* ]]; then
        CLEANED_URL=$(echo "$URL" | sed -e 's/[&?]list=[^&]*//g' -e 's/[&?]index=[^&]*//g')
        if [[ "$CLEANED_URL" == *"watch&"* ]]; then
            CLEANED_URL="${CLEANED_URL/watch&/watch?}"
        fi
        URL="$CLEANED_URL"
    fi
fi

# ── Download Summary ──────────────────────────────────────────────────────────
echo ""
_thick_rule CYAN
printf "  ${BOLD}Download${RESET}\n"
_rule CYAN
printf "  ${DIM}%-14s${RESET}  %s\n" "URL" "$URL"
printf "  ${DIM}%-14s${RESET}  ${CYAN}%s${RESET}\n" "Browser" "$BROWSER"
printf "  ${DIM}%-14s${RESET}  ${CYAN}%s${RESET}\n" "Max res" "${MAX_RES}p"
if [[ "$ALLOW_PLAYLIST" == true ]]; then
    printf "  ${DIM}%-14s${RESET}  ${GREEN}enabled${RESET}\n" "Playlist"
else
    printf "  ${DIM}%-14s${RESET}  ${DIM}disabled (single video)${RESET}\n" "Playlist"
fi
_rule CYAN
echo ""

PLAYLIST_FLAG="--no-playlist"
[[ "$ALLOW_PLAYLIST" == true ]] && PLAYLIST_FLAG="--yes-playlist"

yt-dlp \
    --cookies-from-browser "$BROWSER" \
    -f "$FORMAT" \
    --merge-output-format mp4 \
    --extractor-args "youtubetab:skip=authcheck" \
    $PLAYLIST_FLAG \
    "$URL"
