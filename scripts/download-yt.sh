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
    echo "    iris download-yt ${DIM}[OPTIONS]${RESET} ${BOLD}<URL>${RESET}"
    echo "    iris download ${DIM}[OPTIONS]${RESET} ${BOLD}<URL>${RESET}"
    echo "    download-yt --update-deps"
    echo "    iris download --update-deps"
    echo ""

    render_help_section "DESCRIPTION"
    echo "    ${DIM}Downloads YouTube videos via yt-dlp using browser cookies for"
    echo "    authenticated (age-gated / members-only) downloads."
    echo "    Output is always saved as MP4 (H.264 + AAC)."
    echo "    When multiple resolutions or audio languages are available, you"
    echo "    will be prompted to choose interactively."
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

# ── Fetch Available Formats ───────────────────────────────────────────────────
log_step "Fetching available formats…"
RAW_FORMATS="$(yt-dlp --cookies-from-browser "$BROWSER" --list-formats "$URL" 2>&1)"

if [[ $? -ne 0 ]]; then
    log_err "Failed to fetch format list. Check the URL or run --update-deps."
    echo "$RAW_FORMATS" >&2
    exit "$IRIS_EXIT_FAIL"
fi

# ── Parse Video Resolutions ───────────────────────────────────────────────────
# Extract lines that have an actual resolution (e.g. 1920x1080) but are video-only
# or combined, and collect the height values, deduplicated and sorted descending.
mapfile -t RESOLUTIONS < <(
    echo "$RAW_FORMATS" \
    | grep -E '[0-9]+x[0-9]+' \
    | grep -v 'audio only' \
    | grep -v 'storyboard' \
    | grep -oE '[0-9]+x[0-9]+' \
    | awk -F'x' '{print $2}' \
    | sort -rn \
    | uniq
)

# Filter resolutions down to those ≤ MAX_RES
FILTERED_RES=()
for r in "${RESOLUTIONS[@]}"; do
    if [[ "$r" -le "$MAX_RES" ]]; then
        FILTERED_RES+=("$r")
    fi
done

# Fall back to the full list if everything was filtered out
if [[ "${#FILTERED_RES[@]}" -eq 0 ]]; then
    FILTERED_RES=("${RESOLUTIONS[@]}")
fi

# ── Resolution Selection ──────────────────────────────────────────────────────
CHOSEN_RES=""
if [[ "${#FILTERED_RES[@]}" -gt 1 ]]; then
    echo ""
    _rule CYAN
    printf "  ${BOLD}Select video resolution${RESET}\n"
    _rule CYAN
    for i in "${!FILTERED_RES[@]}"; do
        printf "  ${CYAN}%2d${RESET}  %sp\n" "$((i + 1))" "${FILTERED_RES[$i]}"
    done
    _rule CYAN
    echo ""
    while true; do
        printf "  ${BOLD}Enter choice [1–%d]:${RESET} " "${#FILTERED_RES[@]}"
        read -r RES_CHOICE
        if [[ "$RES_CHOICE" =~ ^[0-9]+$ ]] && \
           [[ "$RES_CHOICE" -ge 1 ]] && \
           [[ "$RES_CHOICE" -le "${#FILTERED_RES[@]}" ]]; then
            CHOSEN_RES="${FILTERED_RES[$((RES_CHOICE - 1))]}"
            break
        fi
        printf "  ${YELLOW}Invalid choice. Try again.${RESET}\n"
    done
elif [[ "${#FILTERED_RES[@]}" -eq 1 ]]; then
    CHOSEN_RES="${FILTERED_RES[0]}"
else
    # No video streams detected — use the flag-supplied cap
    CHOSEN_RES="$MAX_RES"
fi

# ── Parse Audio Languages ─────────────────────────────────────────────────────
# Match lines like: [en] English, [ja] 日本語 - original (original)
# Capture both the lang code and the human-readable name.
# We key on lines that contain "audio only" to avoid picking up subtitle tracks.
declare -a LANG_CODES=()
declare -a LANG_LABELS=()

while IFS= read -r line; do
    # Extract the bracketed language code, e.g. [en] or [es-419]
    lang_code="$(echo "$line" | grep -oE '\[[a-zA-Z0-9_-]+\]' | head -1 | tr -d '[]')"
    [[ -z "$lang_code" ]] && continue

    # Skip if already seen
    already=false
    for c in "${LANG_CODES[@]}"; do
        [[ "$c" == "$lang_code" ]] && already=true && break
    done
    $already && continue

    # Build a readable label: strip the format ID prefix, extract everything after the lang tag
    # e.g. "[en] English - dubbed" or "[ja] 日本語 - original (original)"
    label="$(echo "$line" | grep -oE '\[[a-zA-Z0-9_-]+\].*$' | head -1)"

    LANG_CODES+=("$lang_code")
    LANG_LABELS+=("$label")
done < <(echo "$RAW_FORMATS" | grep "audio only" | grep -E '\[[a-zA-Z0-9_-]+\]')

# ── Language Selection ────────────────────────────────────────────────────────
CHOSEN_LANG=""
if [[ "${#LANG_CODES[@]}" -gt 1 ]]; then
    echo ""
    _rule CYAN
    printf "  ${BOLD}Select audio language${RESET}\n"
    _rule CYAN
    for i in "${!LANG_CODES[@]}"; do
        printf "  ${CYAN}%2d${RESET}  %s\n" "$((i + 1))" "${LANG_LABELS[$i]}"
    done
    _rule CYAN
    echo ""
    while true; do
        printf "  ${BOLD}Enter choice [1–%d]:${RESET} " "${#LANG_CODES[@]}"
        read -r LANG_CHOICE
        if [[ "$LANG_CHOICE" =~ ^[0-9]+$ ]] && \
           [[ "$LANG_CHOICE" -ge 1 ]] && \
           [[ "$LANG_CHOICE" -le "${#LANG_CODES[@]}" ]]; then
            CHOSEN_LANG="${LANG_CODES[$((LANG_CHOICE - 1))]}"
            break
        fi
        printf "  ${YELLOW}Invalid choice. Try again.${RESET}\n"
    done
elif [[ "${#LANG_CODES[@]}" -eq 1 ]]; then
    CHOSEN_LANG="${LANG_CODES[0]}"
fi

# ── Build Format String ───────────────────────────────────────────────────────
# If a specific language was chosen, prefer audio streams tagged with that code.
# yt-dlp language filter syntax: [language=XX]
if [[ -n "$CHOSEN_LANG" ]]; then
    # Best H.264 video up to chosen res  +  best m4a audio for chosen language
    # Fallback chain handles videos without per-language audio tracks.
    FORMAT="bv*[vcodec^=avc][height<=${CHOSEN_RES}][height>0]+ba[ext=m4a][language=${CHOSEN_LANG}]/bv*[vcodec^=avc][height<=${CHOSEN_RES}][height>0]+ba[language=${CHOSEN_LANG}]/bv*[vcodec^=avc][height<=${CHOSEN_RES}][height>0]+ba[ext=m4a]/b[ext=mp4][height<=${CHOSEN_RES}]/b[ext=mp4]/b"
else
    FORMAT="bv*[vcodec^=avc][height<=${CHOSEN_RES}]+ba[ext=m4a]/b[ext=mp4][height<=${CHOSEN_RES}]/b[ext=mp4]/b"
fi

# ── Download Summary ──────────────────────────────────────────────────────────
echo ""
_thick_rule CYAN
printf "  ${BOLD}Download${RESET}\n"
_rule CYAN
printf "  ${DIM}%-14s${RESET}  %s\n" "URL" "$URL"
printf "  ${DIM}%-14s${RESET}  ${CYAN}%s${RESET}\n" "Browser" "$BROWSER"
printf "  ${DIM}%-14s${RESET}  ${CYAN}%sp${RESET}\n" "Resolution" "$CHOSEN_RES"
if [[ -n "$CHOSEN_LANG" ]]; then
    # Find the full label for display
    LANG_DISPLAY=""
    for i in "${!LANG_CODES[@]}"; do
        if [[ "${LANG_CODES[$i]}" == "$CHOSEN_LANG" ]]; then
            LANG_DISPLAY="${LANG_LABELS[$i]}"
            break
        fi
    done
    printf "  ${DIM}%-14s${RESET}  ${CYAN}%s${RESET}\n" "Audio" "$LANG_DISPLAY"
fi
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
