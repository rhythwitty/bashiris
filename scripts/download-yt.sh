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
DEFAULT_MAX_RES="1080"
BROWSER=""
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
    echo "    Interactively prompts for browser, video resolution, and audio"
    echo "    language when multiple choices are available."
    echo "    Use --update-deps to refresh yt-dlp when YouTube changes its player.${RESET}"
    echo ""

    render_help_section "OPTIONS"
    render_help_option "-b, --browser <browser>" "Browser for cookies ${DIM}(prompted if omitted)${RESET}"
    render_help_option "" "                        ${DIM}Supported: chrome, chrome-dev, safari, firefox, vivaldi, opera, opera-gx, brave, edge, none${RESET}"
    render_help_option "-r, --resolution <res>" "Max video resolution ${DIM}(default: ${DEFAULT_MAX_RES}p)${RESET}"
    render_help_option "" "                        ${DIM}Choices: 480, 720, 1080${RESET}"
    render_help_option "-p, --playlist" "Allow entire playlist download"
    render_help_option "-h, --help" "Show this help message"
    render_help_option "--update-deps" "Update yt-dlp to the latest version"
    echo ""

    render_help_section "EXAMPLES"
    echo "    ${DIM}download-yt 'https://youtube.com/watch?v=...'${RESET}"
    echo "    ${DIM}download-yt -b chrome-dev 'https://youtube.com/watch?v=...'${RESET}"
    echo "    ${DIM}download-yt -b firefox 'https://youtube.com/watch?v=...'${RESET}"
    echo "    ${DIM}download-yt -r 720 'https://youtube.com/watch?v=...'${RESET}"
    echo "    ${DIM}download-yt -p 'https://youtube.com/playlist?list=...'${RESET}"
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

if [[ -n "$BROWSER" ]]; then
    case "$BROWSER" in
        chrome | chrome-dev | safari | firefox | vivaldi | opera | opera-gx | brave | edge | none) ;;
        *)
            log_err "Unsupported browser: ${BOLD}${BROWSER}${RESET}."
            log_detail "Supported: chrome, chrome-dev, safari, firefox, vivaldi, opera, opera-gx, brave, edge, none" >&2
            exit "$IRIS_EXIT_USAGE"
            ;;
    esac
fi

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

# ── Browser Selection ─────────────────────────────────────────────────────────
if [[ -z "$BROWSER" ]]; then
    if [[ ! -t 0 ]]; then
        BROWSER="chrome"
    else
        BROWSER_KEYS=("chrome" "chrome-dev" "safari" "firefox" "vivaldi" "opera" "opera-gx" "brave" "edge" "none")
        BROWSER_LABELS=("Chrome" "Chrome for Dev" "Safari" "Firefox" "Vivaldi" "Opera" "Opera GX" "Brave" "Microsoft Edge" "None (no cookies)")

        echo ""
        _rule CYAN
        printf "  ${BOLD}Select browser for cookies${RESET}\n"
        _rule CYAN
        for i in "${!BROWSER_KEYS[@]}"; do
            if [[ $i -eq 0 ]]; then
                printf "  ${CYAN}%2d${RESET}  %s ${DIM}(default)${RESET}\n" "$((i + 1))" "${BROWSER_LABELS[$i]}"
            else
                printf "  ${CYAN}%2d${RESET}  %s\n" "$((i + 1))" "${BROWSER_LABELS[$i]}"
            fi
        done
        _rule CYAN
        echo ""
        while true; do
            printf "  ${BOLD}Enter choice [1–%d, default: 1]:${RESET} " "${#BROWSER_KEYS[@]}"
            read -r BROWSER_CHOICE
            if [[ -z "$BROWSER_CHOICE" ]]; then
                BROWSER="${BROWSER_KEYS[0]}"
                break
            elif [[ "$BROWSER_CHOICE" =~ ^[0-9]+$ ]] && \
                 [[ "$BROWSER_CHOICE" -ge 1 ]] && \
                 [[ "$BROWSER_CHOICE" -le "${#BROWSER_KEYS[@]}" ]]; then
                BROWSER="${BROWSER_KEYS[$((BROWSER_CHOICE - 1))]}"
                break
            fi
            printf "  ${YELLOW}Invalid choice. Try again.${RESET}\n"
        done
    fi
fi

# ── Resolve Browser Cookie Arguments ──────────────────────────────────────────
COOKIE_ARGS=()
BROWSER_DISPLAY=""

case "$BROWSER" in
    chrome)
        COOKIE_ARGS=(--cookies-from-browser "chrome")
        BROWSER_DISPLAY="Chrome"
        ;;
    chrome-dev | "chrome for dev" | "chrome dev")
        BROWSER_DISPLAY="Chrome for Dev"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            dev_dir="$HOME/Library/Application Support/Google/Chrome Dev"
            if [[ -d "$dev_dir" ]]; then
                COOKIE_ARGS=(--cookies-from-browser "chrome:$dev_dir")
            else
                COOKIE_ARGS=(--cookies-from-browser "chrome")
            fi
        else
            dev_dir="$HOME/.config/google-chrome-unstable"
            if [[ -d "$dev_dir" ]]; then
                COOKIE_ARGS=(--cookies-from-browser "chrome:$dev_dir")
            else
                COOKIE_ARGS=(--cookies-from-browser "chrome")
            fi
        fi
        ;;
    safari)
        COOKIE_ARGS=(--cookies-from-browser "safari")
        BROWSER_DISPLAY="Safari"
        ;;
    firefox)
        COOKIE_ARGS=(--cookies-from-browser "firefox")
        BROWSER_DISPLAY="Firefox"
        ;;
    vivaldi)
        COOKIE_ARGS=(--cookies-from-browser "vivaldi")
        BROWSER_DISPLAY="Vivaldi"
        ;;
    opera)
        COOKIE_ARGS=(--cookies-from-browser "opera")
        BROWSER_DISPLAY="Opera"
        ;;
    opera-gx | "opera gx")
        BROWSER_DISPLAY="Opera GX"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            gx_dir="$HOME/Library/Application Support/com.operasoftware.OperaGX"
            if [[ -d "$gx_dir" ]]; then
                COOKIE_ARGS=(--cookies-from-browser "opera:$gx_dir")
            else
                COOKIE_ARGS=(--cookies-from-browser "opera")
            fi
        else
            COOKIE_ARGS=(--cookies-from-browser "opera")
        fi
        ;;
    brave)
        COOKIE_ARGS=(--cookies-from-browser "brave")
        BROWSER_DISPLAY="Brave"
        ;;
    edge)
        COOKIE_ARGS=(--cookies-from-browser "edge")
        BROWSER_DISPLAY="Microsoft Edge"
        ;;
    none | false | off)
        COOKIE_ARGS=()
        BROWSER_DISPLAY="None (no cookies)"
        ;;
    *)
        COOKIE_ARGS=(--cookies-from-browser "$BROWSER")
        BROWSER_DISPLAY="$BROWSER"
        ;;
esac

# ── Fetch Available Formats ───────────────────────────────────────────────────
log_step "Fetching available formats…"
RAW_FORMATS="$(yt-dlp ${COOKIE_ARGS[@]+"${COOKIE_ARGS[@]}"} --list-formats "$URL" 2>&1)"

if [[ $? -ne 0 ]]; then
    log_err "Failed to fetch format list. Check the URL or run --update-deps."
    echo "$RAW_FORMATS" >&2
    exit "$IRIS_EXIT_FAIL"
fi

# ── Parse Video Resolutions ───────────────────────────────────────────────────
# Extract lines that have an actual resolution (e.g. 1920x1080) but are video-only
# or combined, and collect the height values, deduplicated and sorted descending.
# Use while-read instead of mapfile for bash 3.2 compatibility (macOS default).
RESOLUTIONS=()
while IFS= read -r height; do
    [[ -n "$height" ]] && RESOLUTIONS+=("$height")
done < <(
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
        if [[ $i -eq 0 ]]; then
            printf "  ${CYAN}%2d${RESET}  %sp ${DIM}(default)${RESET}\n" "$((i + 1))" "${FILTERED_RES[$i]}"
        else
            printf "  ${CYAN}%2d${RESET}  %sp\n" "$((i + 1))" "${FILTERED_RES[$i]}"
        fi
    done
    _rule CYAN
    echo ""
    while true; do
        printf "  ${BOLD}Enter choice [1–%d, default: 1]:${RESET} " "${#FILTERED_RES[@]}"
        read -r RES_CHOICE
        if [[ -z "$RES_CHOICE" ]]; then
            CHOSEN_RES="${FILTERED_RES[0]}"
            break
        elif [[ "$RES_CHOICE" =~ ^[0-9]+$ ]] && \
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
# Key on "audio only" lines that have a [lang-code] tag.
# yt-dlp lists higher-bitrate (medium) entries before lower-bitrate (low), so
# the first occurrence of each language code is the best quality — we keep that.
LANG_CODES=()
LANG_LABELS=()

while IFS= read -r line; do
    # Extract bracketed language code, e.g. [en] or [es-419]
    lang_code="$(echo "$line" | grep -oE '\[[a-zA-Z0-9_-]+\]' | head -1 | tr -d '[]')"
    [[ -z "$lang_code" ]] && continue

    # Skip duplicates (keep first / highest-quality occurrence)
    already=false
    for c in "${LANG_CODES[@]}"; do
        [[ "$c" == "$lang_code" ]] && already=true && break
    done
    $already && continue

    # Build a clean label: everything from the [lang] tag onward,
    # stripped of trailing quality/format noise like ", low, m4a_dash"
    raw_label="$(echo "$line" | grep -oE '\[[a-zA-Z0-9_-]+\].*$' | head -1)"
    label="$(echo "$raw_label" | sed -E 's/, (low|medium|high),.*$//')"

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
        if [[ $i -eq 0 ]]; then
            printf "  ${CYAN}%2d${RESET}  %s ${DIM}(default)${RESET}\n" "$((i + 1))" "${LANG_LABELS[$i]}"
        else
            printf "  ${CYAN}%2d${RESET}  %s\n" "$((i + 1))" "${LANG_LABELS[$i]}"
        fi
    done
    _rule CYAN
    echo ""
    while true; do
        printf "  ${BOLD}Enter choice [1–%d, default: 1]:${RESET} " "${#LANG_CODES[@]}"
        read -r LANG_CHOICE
        if [[ -z "$LANG_CHOICE" ]]; then
            CHOSEN_LANG="${LANG_CODES[0]}"
            break
        elif [[ "$LANG_CHOICE" =~ ^[0-9]+$ ]] && \
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
printf "  ${DIM}%-14s${RESET}  ${CYAN}%s${RESET}\n" "Browser" "$BROWSER_DISPLAY"
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
    ${COOKIE_ARGS[@]+"${COOKIE_ARGS[@]}"} \
    -f "$FORMAT" \
    --merge-output-format mp4 \
    --extractor-args "youtubetab:skip=authcheck" \
    $PLAYLIST_FLAG \
    "$URL"
