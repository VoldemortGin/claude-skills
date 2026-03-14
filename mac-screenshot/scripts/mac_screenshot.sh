#!/usr/bin/env bash
# mac_screenshot.sh — macOS app automation and screenshot capture

set -euo pipefail

APP_NAME=""
RECIPE_FILE=""
OUTPUT_DIR="./screenshots"
PREFIX="screen"
SHOT_NUM=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $(basename "$0") --app-name <name> [options]

Options:
  --app-name <name>     Required. Process name of the target app (e.g. "Pervius", "Safari")
  --recipe <file>       Optional. Recipe file with commands. If omitted, reads from stdin.
  --output-dir <dir>    Optional. Directory for screenshots. Default: ./screenshots
  --prefix <prefix>     Optional. Prefix for auto-numbered screenshots. Default: "screen"
  -h, --help            Show this help message

Commands in recipe file:
  ACTIVATE                       Bring app to foreground
  LAUNCH <path_or_bundle_id>     Open an app by path or bundle ID
  QUIT                           Gracefully quit the app
  KILL                           Force kill the app
  RESIZE <width> <height>        Resize the frontmost window
  MOVE <x> <y>                   Move window to position
  FULLSCREEN                     Toggle fullscreen
  WAIT <seconds>                 Sleep (supports decimals like 0.5)
  CLICK <x> <y>                  Click at coordinates relative to window
  RIGHT_CLICK <x> <y>            Right-click at coordinates
  DOUBLE_CLICK <x> <y>           Double-click at coordinates
  TYPE <text>                    Type text via keystroke
  KEY <key> [modifiers]          Press a key combo (e.g. KEY return, KEY w command)
  SCROLL <direction> <amount>    Scroll up/down/left/right
  SIDEBAR <item_name>            Click a sidebar item by name
  MENU <menu_name> <item_name>   Click a menu bar item
  BUTTON <button_name>           Click a button by name/title
  TAB <tab_name>                 Click a tab by name
  CHECKBOX <name> on|off         Toggle a checkbox
  TEXTFIELD <name_or_index> <value>  Set text field value
  POPUP <name> <value>           Select from popup button/dropdown
  TOOLBAR <item_name>            Click toolbar item
  SCREENSHOT [filename]          Capture the app window
  SCREENSHOT_FULL [filename]     Capture entire screen
  SCREENSHOT_REGION <x> <y> <w> <h> [filename]  Capture a screen region
  DARK_MODE on|off               Toggle system appearance
  SET_APPEARANCE light|dark|auto Set system appearance
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --app-name)   APP_NAME="$2"; shift 2 ;;
            --recipe)     RECIPE_FILE="$2"; shift 2 ;;
            --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
            --prefix)     PREFIX="$2"; shift 2 ;;
            -h|--help)    usage; exit 0 ;;
            *) echo "Unknown argument: $1"; usage; exit 1 ;;
        esac
    done

    if [[ -z "$APP_NAME" ]]; then
        echo "Error: --app-name is required"
        usage
        exit 1
    fi
}

ok()   { echo -e "  ${GREEN}OK${NC} $1"; }
err()  { echo -e "  ${RED}ERR${NC} $1"; }
info() { echo -e "  ${CYAN}>>>${NC} $1"; }

# ─── Core functions ──────────────────────────────────

activate_app() {
    osascript -e "tell application \"$APP_NAME\" to activate" 2>/dev/null
    sleep 0.3
}

get_cg_window_id() {
    python3 -c "
import Quartz
wl = Quartz.CGWindowListCopyWindowInfo(Quartz.kCGWindowListOptionOnScreenOnly, Quartz.kCGNullWindowID)
for w in wl:
    if w.get('kCGWindowOwnerName') == '$APP_NAME' and w.get('kCGWindowLayer', 99) == 0:
        print(w['kCGWindowNumber'])
        break
" 2>/dev/null
}

get_window_position() {
    osascript -e "tell application \"System Events\" to tell process \"$APP_NAME\" to get position of window 1" 2>/dev/null
}

get_window_size() {
    osascript -e "tell application \"System Events\" to tell process \"$APP_NAME\" to get size of window 1" 2>/dev/null
}

do_screenshot() {
    local filename="$1"
    activate_app
    sleep 0.3
    local wid
    wid=$(get_cg_window_id)
    if [[ -n "$wid" ]]; then
        screencapture -l "$wid" "$OUTPUT_DIR/$filename" 2>/dev/null
        ok "SCREENSHOT → $OUTPUT_DIR/$filename"
    else
        err "SCREENSHOT — could not find window for $APP_NAME"
    fi
}

auto_screenshot_name() {
    ((SHOT_NUM++))
    printf "%s_%02d.png" "$PREFIX" "$SHOT_NUM"
}

do_sidebar() {
    local item="$1"
    activate_app
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                -- Pattern 1: group > splitter group > group > scroll area > outline (SwiftUI NavigationSplitView with sidebar header)
                try
                    set ol to outline 1 of scroll area 1 of group 1 of splitter group 1 of group 1 of window 1
                    set numRows to count of rows of ol
                    repeat with i from 1 to numRows
                        set r to row i of ol
                        try
                            set ue to UI element 1 of r
                            set txt to static text 1 of ue
                            if value of txt contains \"$item\" then
                                select r
                                return true
                            end if
                        end try
                    end repeat
                end try
                -- Pattern 2: splitter group > scroll area > outline (simple NavigationSplitView)
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
                        try
                            set ue to UI element 1 of r
                            if value of static text 1 of ue contains \"$item\" then
                                select r
                                return true
                            end if
                        end try
                    end repeat
                end try
                -- Pattern 3: group > splitter group > scroll area > outline
                try
                    set ol to outline 1 of scroll area 1 of group 1 of splitter group 1 of window 1
                    set numRows to count of rows of ol
                    repeat with i from 1 to numRows
                        set r to row i of ol
                        try
                            if value of static text 1 of r contains \"$item\" then
                                select r
                                return true
                            end if
                        end try
                        try
                            set ue to UI element 1 of r
                            if value of static text 1 of ue contains \"$item\" then
                                select r
                                return true
                            end if
                        end try
                    end repeat
                end try
                -- Pattern 4: enumerate all outlines in all splitter groups
                try
                    set sgs to every splitter group of window 1
                    repeat with sg in sgs
                        set sas to every scroll area of sg
                        repeat with sa in sas
                            try
                                set ol to outline 1 of sa
                                set numRows to count of rows of ol
                                repeat with i from 1 to numRows
                                    set r to row i of ol
                                    try
                                        set ue to UI element 1 of r
                                        set txt to static text 1 of ue
                                        if value of txt contains \"$item\" then
                                            select r
                                            return true
                                        end if
                                    end try
                                    try
                                        if value of static text 1 of r contains \"$item\" then
                                            select r
                                            return true
                                        end if
                                    end try
                                end repeat
                            end try
                        end repeat
                    end repeat
                end try
                return false
            end tell
        end tell
    " 2>/dev/null
    sleep 0.3
}

do_menu() {
    local menu_name="$1"
    local item_name="$2"
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                click menu item \"$item_name\" of menu \"$menu_name\" of menu bar 1
            end tell
        end tell
    " 2>/dev/null
}

do_button() {
    local btn_name="$1"
    activate_app
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                click (first button whose title contains \"$btn_name\" or description contains \"$btn_name\") of window 1
            end tell
        end tell
    " 2>/dev/null
}

do_tab() {
    local tab_name="$1"
    activate_app
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                try
                    click (first radio button whose title contains \"$tab_name\") of first tab group of window 1
                    return true
                end try
                try
                    click (first radio button whose title contains \"$tab_name\") of first toolbar of window 1
                    return true
                end try
                try
                    click (first button whose title contains \"$tab_name\") of first group of first toolbar of window 1
                    return true
                end try
                return false
            end tell
        end tell
    " 2>/dev/null
}

do_checkbox() {
    local name="$1"
    local desired="$2"
    activate_app
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                set cb to (first checkbox whose title contains \"$name\") of window 1
                set currentValue to value of cb
                if \"$desired\" is \"on\" and currentValue is 0 then
                    click cb
                else if \"$desired\" is \"off\" and currentValue is 1 then
                    click cb
                end if
            end tell
        end tell
    " 2>/dev/null
}

do_textfield() {
    local name_or_idx="$1"
    local value="$2"
    activate_app
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                try
                    set tf to text field ${name_or_idx} of window 1
                on error
                    set tf to (first text field whose description contains \"${name_or_idx}\") of window 1
                end try
                set focused of tf to true
                set value of tf to \"${value}\"
            end tell
        end tell
    " 2>/dev/null
}

do_popup() {
    local name="$1"
    local value="$2"
    activate_app
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                set pb to (first pop up button whose description contains \"$name\") of window 1
                click pb
                delay 0.3
                click (first menu item whose title contains \"$value\") of menu 1 of pb
            end tell
        end tell
    " 2>/dev/null
}

do_toolbar() {
    local item_name="$1"
    activate_app
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                click (first button whose description contains \"$item_name\" or title contains \"$item_name\") of toolbar 1 of window 1
            end tell
        end tell
    " 2>/dev/null
}

do_click() {
    local x=$1 y=$2
    activate_app
    local pos
    pos=$(get_window_position)
    local win_x win_y
    win_x=$(echo "$pos" | tr -d ' ' | cut -d',' -f1)
    win_y=$(echo "$pos" | tr -d ' ' | cut -d',' -f2)
    local abs_x=$(( win_x + x ))
    local abs_y=$(( win_y + y ))
    osascript -e "
        tell application \"System Events\"
            click at {$abs_x, $abs_y}
        end tell
    " 2>/dev/null
}

do_right_click() {
    local x=$1 y=$2
    activate_app
    local pos
    pos=$(get_window_position)
    local win_x win_y
    win_x=$(echo "$pos" | tr -d ' ' | cut -d',' -f1)
    win_y=$(echo "$pos" | tr -d ' ' | cut -d',' -f2)
    local abs_x=$(( win_x + x ))
    local abs_y=$(( win_y + y ))
    if command -v cliclick &>/dev/null; then
        cliclick rc:$abs_x,$abs_y
    else
        osascript -e "
            tell application \"System Events\"
                key down control
                click at {$abs_x, $abs_y}
                key up control
            end tell
        " 2>/dev/null
    fi
}

do_type() {
    local text="$1"
    activate_app
    osascript -e "
        tell application \"System Events\"
            keystroke \"$text\"
        end tell
    " 2>/dev/null
}

do_key() {
    local key="$1"
    shift
    local mods=("$@")
    activate_app

    local using_parts=()
    for mod in "${mods[@]}"; do
        case "$mod" in
            command|cmd)   using_parts+=("command down") ;;
            shift)         using_parts+=("shift down") ;;
            option|alt)    using_parts+=("option down") ;;
            control|ctrl)  using_parts+=("control down") ;;
        esac
    done

    local using_clause=""
    if [[ ${#using_parts[@]} -gt 0 ]]; then
        using_clause=" using {$(IFS=', '; echo "${using_parts[*]}")}"
    fi

    local key_code=""
    case "$key" in
        return|enter)     key_code="36" ;;
        tab)              key_code="48" ;;
        escape|esc)       key_code="53" ;;
        delete|backspace) key_code="51" ;;
        space)            key_code="49" ;;
        up)               key_code="126" ;;
        down)             key_code="125" ;;
        left)             key_code="123" ;;
        right)            key_code="124" ;;
        f1)               key_code="122" ;;
        f2)               key_code="120" ;;
        f3)               key_code="99" ;;
        f4)               key_code="118" ;;
        f5)               key_code="96" ;;
        f6)               key_code="97" ;;
        f7)               key_code="98" ;;
        f8)               key_code="100" ;;
        f9)               key_code="101" ;;
        f10)              key_code="109" ;;
        f11)              key_code="103" ;;
        f12)              key_code="111" ;;
    esac

    if [[ -n "$key_code" ]]; then
        osascript -e "tell application \"System Events\" to key code $key_code$using_clause" 2>/dev/null
    else
        osascript -e "tell application \"System Events\" to keystroke \"$key\"$using_clause" 2>/dev/null
    fi
}

do_scroll() {
    local direction="$1"
    local amount="${2:-3}"
    activate_app
    case "$direction" in
        up)
            for ((i=0; i<amount; i++)); do
                osascript -e 'tell application "System Events" to key code 126' 2>/dev/null
            done
            ;;
        down)
            for ((i=0; i<amount; i++)); do
                osascript -e 'tell application "System Events" to key code 125' 2>/dev/null
            done
            ;;
        left)
            for ((i=0; i<amount; i++)); do
                osascript -e 'tell application "System Events" to key code 123' 2>/dev/null
            done
            ;;
        right)
            for ((i=0; i<amount; i++)); do
                osascript -e 'tell application "System Events" to key code 124' 2>/dev/null
            done
            ;;
        *)
            err "SCROLL: unknown direction '$direction'"
            ;;
    esac
}

do_resize() {
    local w=$1 h=$2
    osascript -e "tell application \"System Events\" to tell process \"$APP_NAME\" to set size of window 1 to {$w, $h}" 2>/dev/null
}

do_move() {
    local x=$1 y=$2
    osascript -e "tell application \"System Events\" to tell process \"$APP_NAME\" to set position of window 1 to {$x, $y}" 2>/dev/null
}

do_dark_mode() {
    local mode="$1"
    case "$mode" in
        on|dark)
            osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true' 2>/dev/null
            ;;
        off|light)
            osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false' 2>/dev/null
            ;;
        auto)
            osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to not dark mode of appearance preferences' 2>/dev/null
            ;;
    esac
}

# ─── Main dispatcher ──────────────────────────────────

run_recipe() {
    local line_num=0
    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        ((line_num++))
        local line
        line=$(echo "$raw_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$line" || "$line" == \#* ]] && continue

        local cmd
        cmd=$(echo "$line" | awk '{print $1}')
        local args
        args=$(echo "$line" | cut -d' ' -f2-)
        [[ "$cmd" == "$args" ]] && args=""

        echo -e "${YELLOW}[$line_num]${NC} $line"

        case "$cmd" in
            ACTIVATE)
                activate_app
                ok "ACTIVATE $APP_NAME"
                ;;
            LAUNCH)
                open "$args" 2>/dev/null || open -b "$args" 2>/dev/null
                sleep 1
                ok "LAUNCH $args"
                ;;
            QUIT)
                osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null
                sleep 1
                ok "QUIT $APP_NAME"
                ;;
            KILL)
                pkill -9 -f "$APP_NAME" 2>/dev/null || true
                sleep 0.5
                ok "KILL $APP_NAME"
                ;;
            RESIZE)
                local rw rh
                rw=$(echo "$args" | awk '{print $1}')
                rh=$(echo "$args" | awk '{print $2}')
                do_resize "$rw" "$rh"
                sleep 0.2
                ok "RESIZE ${rw}x${rh}"
                ;;
            MOVE)
                local mx my
                mx=$(echo "$args" | awk '{print $1}')
                my=$(echo "$args" | awk '{print $2}')
                do_move "$mx" "$my"
                ok "MOVE $mx,$my"
                ;;
            FULLSCREEN)
                activate_app
                osascript -e "tell application \"System Events\" to tell process \"$APP_NAME\" to set value of attribute \"AXFullScreen\" of window 1 to true" 2>/dev/null
                ok "FULLSCREEN"
                ;;
            WAIT)
                sleep "${args:-1}"
                ok "WAIT ${args:-1}s"
                ;;
            CLICK)
                local cx cy
                cx=$(echo "$args" | awk '{print $1}')
                cy=$(echo "$args" | awk '{print $2}')
                do_click "$cx" "$cy"
                ok "CLICK $cx,$cy"
                ;;
            RIGHT_CLICK)
                local rcx rcy
                rcx=$(echo "$args" | awk '{print $1}')
                rcy=$(echo "$args" | awk '{print $2}')
                do_right_click "$rcx" "$rcy"
                ok "RIGHT_CLICK $rcx,$rcy"
                ;;
            DOUBLE_CLICK)
                local dcx dcy
                dcx=$(echo "$args" | awk '{print $1}')
                dcy=$(echo "$args" | awk '{print $2}')
                do_click "$dcx" "$dcy"
                sleep 0.05
                do_click "$dcx" "$dcy"
                ok "DOUBLE_CLICK $dcx,$dcy"
                ;;
            TYPE)
                do_type "$args"
                ok "TYPE \"$args\""
                ;;
            KEY)
                local key_name key_mods
                key_name=$(echo "$args" | awk '{print $1}')
                key_mods=$(echo "$args" | cut -d' ' -f2-)
                [[ "$key_name" == "$key_mods" ]] && key_mods=""
                if [[ -n "$key_mods" ]]; then
                    do_key "$key_name" $key_mods
                else
                    do_key "$key_name"
                fi
                ok "KEY $args"
                ;;
            SCROLL)
                local sdir samt
                sdir=$(echo "$args" | awk '{print $1}')
                samt=$(echo "$args" | awk '{print $2}')
                do_scroll "$sdir" "${samt:-3}"
                ok "SCROLL $sdir ${samt:-3}"
                ;;
            SIDEBAR)
                do_sidebar "$args"
                ok "SIDEBAR \"$args\""
                ;;
            MENU)
                local mname mitem
                mname=$(echo "$args" | awk '{print $1}')
                mitem=$(echo "$args" | cut -d' ' -f2-)
                do_menu "$mname" "$mitem"
                ok "MENU $mname → $mitem"
                ;;
            BUTTON)
                do_button "$args"
                ok "BUTTON \"$args\""
                ;;
            TAB)
                do_tab "$args"
                ok "TAB \"$args\""
                ;;
            CHECKBOX)
                local cbname cbstate
                cbname=$(echo "$args" | awk '{print $1}')
                cbstate=$(echo "$args" | awk '{print $2}')
                do_checkbox "$cbname" "$cbstate"
                ok "CHECKBOX \"$cbname\" $cbstate"
                ;;
            TEXTFIELD)
                local tfname tfval
                tfname=$(echo "$args" | awk '{print $1}')
                tfval=$(echo "$args" | cut -d' ' -f2-)
                do_textfield "$tfname" "$tfval"
                ok "TEXTFIELD \"$tfname\" = \"$tfval\""
                ;;
            POPUP)
                local pbname pbval
                pbname=$(echo "$args" | awk '{print $1}')
                pbval=$(echo "$args" | cut -d' ' -f2-)
                do_popup "$pbname" "$pbval"
                ok "POPUP \"$pbname\" → \"$pbval\""
                ;;
            TOOLBAR)
                do_toolbar "$args"
                ok "TOOLBAR \"$args\""
                ;;
            SCREENSHOT)
                local sfname="${args:-$(auto_screenshot_name)}"
                [[ "$sfname" != *.png ]] && sfname="${sfname}.png"
                do_screenshot "$sfname"
                ;;
            SCREENSHOT_FULL)
                local sffname="${args:-$(auto_screenshot_name)}"
                [[ "$sffname" != *.png ]] && sffname="${sffname}.png"
                screencapture "$OUTPUT_DIR/$sffname" 2>/dev/null
                ok "SCREENSHOT_FULL → $OUTPUT_DIR/$sffname"
                ;;
            SCREENSHOT_REGION)
                local srx sry srw srh srfname
                srx=$(echo "$args" | awk '{print $1}')
                sry=$(echo "$args" | awk '{print $2}')
                srw=$(echo "$args" | awk '{print $3}')
                srh=$(echo "$args" | awk '{print $4}')
                srfname=$(echo "$args" | awk '{print $5}')
                [[ -z "$srfname" ]] && srfname=$(auto_screenshot_name)
                [[ "$srfname" != *.png ]] && srfname="${srfname}.png"
                screencapture -R "${srx},${sry},${srw},${srh}" "$OUTPUT_DIR/$srfname" 2>/dev/null
                ok "SCREENSHOT_REGION → $OUTPUT_DIR/$srfname"
                ;;
            DARK_MODE)
                do_dark_mode "$args"
                ok "DARK_MODE $args"
                ;;
            SET_APPEARANCE)
                do_dark_mode "$args"
                ok "SET_APPEARANCE $args"
                ;;
            *)
                err "Unknown command: $cmd"
                ;;
        esac
    done < "${RECIPE_FILE:-/dev/stdin}"
}

# ─── Entry point ──────────────────────────────────

main() {
    parse_args "$@"
    mkdir -p "$OUTPUT_DIR"
    info "App: $APP_NAME | Output: $OUTPUT_DIR | Prefix: $PREFIX"
    run_recipe
    info "Done. Screenshots saved to $OUTPUT_DIR"
}

main "$@"
