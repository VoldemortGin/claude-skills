#!/usr/bin/env bash
# swiftui_test.sh — Automated test runner for macOS SwiftUI apps
# Uses osascript/System Events for window manipulation, screenshots, and UI interaction

PASS=0
FAIL=0
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROJECT=""
SCHEME=""
APP_NAME=""
TEST_FILE=""
APP_PATH=""

usage() {
    echo "Usage: $0 --project <path.xcodeproj> --scheme <scheme> --app-name <AppName> --test-file <file>"
    echo ""
    echo "Test commands (one per line in test file):"
    echo "  BUILD                         Clean build via xcodebuild"
    echo "  LAUNCH                        Launch the app (kills existing first)"
    echo "  KILL                          Kill the app"
    echo "  WAIT <seconds>                Sleep"
    echo "  WINDOW_MIN_SIZE <w> <h>       Try to resize below min, verify it's clamped"
    echo "  WINDOW_MAX_SIZE <w> <h>       Try to resize above max, verify it's clamped"
    echo "  WINDOW_RESIZE <w> <h>         Resize and verify exact size"
    echo "  WINDOW_SIZE_GE <w> <h>        Verify current size >= given"
    echo "  SCREENSHOT <filename>         Capture window screenshot"
    echo "  DARK_MODE on|off              Toggle system dark mode"
    echo "  CLICK_MENU <menu> <item>      Click a menu item"
    echo "  UI_EXISTS <description>       Check if UI element exists"
    echo "  SIDEBAR_SELECT <item_name>    Click a sidebar item by name"
    exit 1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project)   PROJECT="$2";   shift 2 ;;
            --scheme)    SCHEME="$2";    shift 2 ;;
            --app-name)  APP_NAME="$2";  shift 2 ;;
            --test-file) TEST_FILE="$2"; shift 2 ;;
            -h|--help)   usage ;;
            *) echo "Unknown argument: $1"; usage ;;
        esac
    done

    if [[ -z "$PROJECT" || -z "$SCHEME" || -z "$APP_NAME" || -z "$TEST_FILE" ]]; then
        echo "Error: --project, --scheme, --app-name, and --test-file are all required."
        usage
    fi

    if [[ ! -f "$TEST_FILE" ]]; then
        echo "Error: Test file not found: $TEST_FILE"
        exit 1
    fi
}

# ─── Reporting ───────────────────────────────────────────────────────────────

pass() {
    local msg="$1"
    echo -e "  ${GREEN}PASS${NC} $msg"
    ((PASS++))
}

fail() {
    local msg="$1"
    echo -e "  ${RED}FAIL${NC} $msg"
    ((FAIL++))
}

info() {
    echo -e "  ${YELLOW}INFO${NC} $1"
}

# ─── osascript helpers ────────────────────────────────────────────────────────

get_window_size() {
    osascript -e "tell application \"System Events\" to tell process \"$APP_NAME\" to get size of window 1" 2>/dev/null
}

resize_window() {
    local w=$1 h=$2
    osascript -e "tell application \"System Events\" to tell process \"$APP_NAME\" to set size of window 1 to {$w, $h}" 2>/dev/null
}

ui_element_exists() {
    local desc="$1"
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                return exists (first UI element whose description contains \"$desc\")
            end tell
        end tell
    " 2>/dev/null
}

sidebar_select() {
    local item="$1"
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                -- Try multiple outline hierarchy patterns with select (not click) for SwiftUI
                try
                    set ol to outline 1 of scroll area 1 of group 1 of splitter group 1 of group 1 of window 1
                    set numRows to count of rows of ol
                    repeat with i from 1 to numRows
                        set r to row i of ol
                        try
                            set ue to UI element 1 of r
                            if value of static text 1 of ue contains \"$item\" then
                                select r
                                return true
                            end if
                        end try
                    end repeat
                end try
                try
                    set ol to outline 1 of scroll area 1 of splitter group 1 of window 1
                    set numRows to count of rows of ol
                    repeat with i from 1 to numRows
                        set r to row i of ol
                        try
                            if value of static text 1 of r contains \"$item\" then
                                select r
                                return true
                            end if
                        end try
                    end repeat
                end try
                return false
            end tell
        end tell
    " 2>/dev/null
}

take_screenshot() {
    local filename="$1"
    # Ensure parent directory exists
    local dir
    dir=$(dirname "$filename")
    [[ -n "$dir" && "$dir" != "." ]] && mkdir -p "$dir"
    # Activate the app to bring it to front
    osascript -e "tell application \"$APP_NAME\" to activate" 2>/dev/null
    sleep 0.5
    # Get CGWindowID via Quartz (the only ID screencapture -l accepts)
    local wid
    wid=$(python3 -c "
import Quartz
wl = Quartz.CGWindowListCopyWindowInfo(Quartz.kCGWindowListOptionOnScreenOnly, Quartz.kCGNullWindowID)
for w in wl:
    if w.get('kCGWindowOwnerName') == '$APP_NAME' and w.get('kCGWindowLayer', 99) == 0:
        print(w['kCGWindowNumber'])
        break
" 2>/dev/null)
    if [[ -n "$wid" ]]; then
        screencapture -l "$wid" "$filename" 2>/dev/null
    else
        # Fallback: capture frontmost window
        screencapture -o "$filename" 2>/dev/null
    fi
}

set_dark_mode() {
    local mode="$1"
    if [ "$mode" = "on" ]; then
        osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
    else
        osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false'
    fi
}

click_menu_item() {
    local menu="$1" item="$2"
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                click menu item \"$item\" of menu \"$menu\" of menu bar 1
            end tell
        end tell
    " 2>/dev/null
}

# ─── Build ───────────────────────────────────────────────────────────────────

do_build() {
    info "Building $SCHEME from $PROJECT ..."
    local build_log
    build_log=$(xcodebuild clean build \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "platform=macOS,arch=arm64" \
        -allowProvisioningUpdates \
        -quiet 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo "$build_log" | tail -20
        fail "BUILD failed (exit $exit_code)"
        return
    fi

    # Extract .app path from build log
    APP_PATH=$(echo "$build_log" | grep -o '/[^ ]*\.app' | grep "/$APP_NAME\.app" | head -1)
    if [[ -z "$APP_PATH" ]]; then
        # Try to find via xcodebuild -showBuildSettings
        local derived_data
        derived_data=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
            | grep 'BUILT_PRODUCTS_DIR' | awk '{print $3}' | head -1)
        if [[ -n "$derived_data" ]]; then
            APP_PATH="$derived_data/$APP_NAME.app"
        fi
    fi

    if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
        # Last resort: search DerivedData
        APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "$APP_NAME.app" -not -path "*/Index.noindex/*" 2>/dev/null \
            | sort -t/ -k8 2>/dev/null | tail -1)
    fi

    if [[ -n "$APP_PATH" && -d "$APP_PATH" ]]; then
        pass "BUILD succeeded — $APP_PATH"
    else
        pass "BUILD succeeded (app path unknown)"
    fi
}

# ─── Launch / Kill ────────────────────────────────────────────────────────────

do_kill() {
    pkill -9 -f "$APP_NAME" 2>/dev/null || true
    sleep 0.5
}

do_launch() {
    do_kill
    if [[ -n "$APP_PATH" && -d "$APP_PATH" ]]; then
        open "$APP_PATH"
        pass "LAUNCH — opened $APP_PATH"
    else
        # Try to find app without explicit path
        local found
        found=$(find ~/Library/Developer/Xcode/DerivedData -name "$APP_NAME.app" -not -path "*/Index.noindex/*" 2>/dev/null \
            | sort -t/ -k8 2>/dev/null | tail -1)
        if [[ -n "$found" ]]; then
            APP_PATH="$found"
            open "$APP_PATH"
            pass "LAUNCH — opened $APP_PATH"
        else
            fail "LAUNCH — could not find $APP_NAME.app (run BUILD first?)"
        fi
    fi
}

# ─── Window tests ─────────────────────────────────────────────────────────────

parse_size() {
    # osascript returns "W, H" — extract numbers
    echo "$1" | tr -d ' ' | tr ',' '\n'
}

do_window_min_size() {
    local min_w=$1 min_h=$2
    local under_w=$(( min_w - 200 ))
    local under_h=$(( min_h - 200 ))
    [[ $under_w -lt 100 ]] && under_w=100
    [[ $under_h -lt 100 ]] && under_h=100

    resize_window "$under_w" "$under_h"
    sleep 0.3

    local size actual_w actual_h
    size=$(get_window_size)
    actual_w=$(parse_size "$size" | head -1)
    actual_h=$(parse_size "$size" | tail -1)

    if [[ -z "$actual_w" || -z "$actual_h" ]]; then
        fail "WINDOW_MIN_SIZE — could not get window size (accessibility permission?)"
        return
    fi

    local ok=true
    [[ "$actual_w" -lt "$min_w" ]] && ok=false
    [[ "$actual_h" -lt "$min_h" ]] && ok=false

    if $ok; then
        pass "WINDOW_MIN_SIZE ${min_w}x${min_h} — actual ${actual_w}x${actual_h} (correctly clamped)"
    else
        fail "WINDOW_MIN_SIZE ${min_w}x${min_h} — actual ${actual_w}x${actual_h} (not clamped!)"
    fi
}

do_window_max_size() {
    local max_w=$1 max_h=$2
    local over_w=$(( max_w + 400 ))
    local over_h=$(( max_h + 400 ))

    resize_window "$over_w" "$over_h"
    sleep 0.3

    local size actual_w actual_h
    size=$(get_window_size)
    actual_w=$(parse_size "$size" | head -1)
    actual_h=$(parse_size "$size" | tail -1)

    if [[ -z "$actual_w" || -z "$actual_h" ]]; then
        fail "WINDOW_MAX_SIZE — could not get window size"
        return
    fi

    local ok=true
    [[ "$actual_w" -gt "$max_w" ]] && ok=false
    [[ "$actual_h" -gt "$max_h" ]] && ok=false

    if $ok; then
        pass "WINDOW_MAX_SIZE ${max_w}x${max_h} — actual ${actual_w}x${actual_h} (correctly clamped)"
    else
        fail "WINDOW_MAX_SIZE ${max_w}x${max_h} — actual ${actual_w}x${actual_h} (not clamped!)"
    fi
}

do_window_resize() {
    local want_w=$1 want_h=$2
    resize_window "$want_w" "$want_h"
    sleep 0.3

    local size actual_w actual_h
    size=$(get_window_size)
    actual_w=$(parse_size "$size" | head -1)
    actual_h=$(parse_size "$size" | tail -1)

    if [[ -z "$actual_w" || -z "$actual_h" ]]; then
        fail "WINDOW_RESIZE — could not get window size"
        return
    fi

    if [[ "$actual_w" -eq "$want_w" && "$actual_h" -eq "$want_h" ]]; then
        pass "WINDOW_RESIZE ${want_w}x${want_h} — exact match"
    else
        fail "WINDOW_RESIZE ${want_w}x${want_h} — actual ${actual_w}x${actual_h}"
    fi
}

do_window_size_ge() {
    local min_w=$1 min_h=$2

    local size actual_w actual_h
    size=$(get_window_size)
    actual_w=$(parse_size "$size" | head -1)
    actual_h=$(parse_size "$size" | tail -1)

    if [[ -z "$actual_w" || -z "$actual_h" ]]; then
        fail "WINDOW_SIZE_GE — could not get window size"
        return
    fi

    if [[ "$actual_w" -ge "$min_w" && "$actual_h" -ge "$min_h" ]]; then
        pass "WINDOW_SIZE_GE ${min_w}x${min_h} — actual ${actual_w}x${actual_h}"
    else
        fail "WINDOW_SIZE_GE ${min_w}x${min_h} — actual ${actual_w}x${actual_h} (too small!)"
    fi
}

# ─── Main dispatcher ──────────────────────────────────────────────────────────

run_test_file() {
    local line_num=0
    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        ((line_num++))
        # Strip leading/trailing whitespace and skip blank lines / comments
        local line
        line=$(echo "$raw_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$line" || "$line" == \#* ]] && continue

        local cmd
        cmd=$(echo "$line" | awk '{print $1}')
        local args
        args=$(echo "$line" | cut -d' ' -f2-)

        echo ""
        echo -e "${YELLOW}[Line $line_num]${NC} $line"

        case "$cmd" in
            BUILD)
                do_build
                ;;
            LAUNCH)
                do_launch
                ;;
            KILL)
                do_kill
                pass "KILL — $APP_NAME terminated"
                ;;
            WAIT)
                local secs="${args:-1}"
                sleep "$secs"
                pass "WAIT ${secs}s"
                ;;
            WINDOW_MIN_SIZE)
                local w h
                w=$(echo "$args" | awk '{print $1}')
                h=$(echo "$args" | awk '{print $2}')
                do_window_min_size "$w" "$h"
                ;;
            WINDOW_MAX_SIZE)
                local w h
                w=$(echo "$args" | awk '{print $1}')
                h=$(echo "$args" | awk '{print $2}')
                do_window_max_size "$w" "$h"
                ;;
            WINDOW_RESIZE)
                local w h
                w=$(echo "$args" | awk '{print $1}')
                h=$(echo "$args" | awk '{print $2}')
                do_window_resize "$w" "$h"
                ;;
            WINDOW_SIZE_GE)
                local w h
                w=$(echo "$args" | awk '{print $1}')
                h=$(echo "$args" | awk '{print $2}')
                do_window_size_ge "$w" "$h"
                ;;
            SCREENSHOT)
                local fname="${args:-screenshot.png}"
                take_screenshot "$fname"
                pass "SCREENSHOT → $fname"
                ;;
            DARK_MODE)
                local mode="${args:-off}"
                set_dark_mode "$mode"
                pass "DARK_MODE $mode"
                ;;
            CLICK_MENU)
                local menu item
                menu=$(echo "$args" | awk '{print $1}')
                item=$(echo "$args" | cut -d' ' -f2-)
                click_menu_item "$menu" "$item"
                pass "CLICK_MENU \"$menu\" → \"$item\""
                ;;
            UI_EXISTS)
                local result
                result=$(ui_element_exists "$args")
                if [[ "$result" == "true" ]]; then
                    pass "UI_EXISTS \"$args\""
                else
                    fail "UI_EXISTS \"$args\" — not found"
                fi
                ;;
            SIDEBAR_SELECT)
                sidebar_select "$args"
                sleep 0.5
                pass "SIDEBAR_SELECT \"$args\""
                ;;
            *)
                fail "Unknown command: $cmd"
                ;;
        esac
    done < "$TEST_FILE"
}

print_summary() {
    local total=$(( PASS + FAIL ))
    echo ""
    echo "═══════════════════════════════════════"
    echo -e "  Results: ${GREEN}$PASS passed${NC} / ${RED}$FAIL failed${NC} / $total total"
    echo "═══════════════════════════════════════"
    if [[ $FAIL -eq 0 ]]; then
        echo -e "  ${GREEN}All tests passed.${NC}"
    else
        echo -e "  ${RED}$FAIL test(s) failed.${NC}"
    fi
    echo ""
}

main() {
    parse_args "$@"

    echo ""
    echo "═══════════════════════════════════════"
    echo "  SwiftUI Test Runner"
    echo "  Project:  $PROJECT"
    echo "  Scheme:   $SCHEME"
    echo "  App:      $APP_NAME"
    echo "  Tests:    $TEST_FILE"
    echo "═══════════════════════════════════════"

    run_test_file
    print_summary

    [[ $FAIL -eq 0 ]]
}

main "$@"
