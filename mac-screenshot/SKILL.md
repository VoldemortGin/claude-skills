---
name: mac-screenshot
description: >
  Automated macOS app UI interaction and screenshot capture tool. Use when you need to:
  (1) Take screenshots of any macOS application window,
  (2) Automate UI interactions like clicking buttons, selecting sidebar items, navigating menus,
  (3) Document app UI across different states (light/dark mode, different pages),
  (4) Perform click, type, scroll operations before capturing.
  Triggers: screenshot, capture UI, app screenshot, take screenshot, UI automation, osascript,
  截图, 应用截图, UI自动化, 界面截图
---

## Quick start

```bash
bash /Users/linhan/.claude/skills/mac-screenshot/scripts/mac_screenshot.sh \
  --app-name "Pervius" \
  --recipe /Users/linhan/.claude/skills/mac-screenshot/scripts/examples/pervius_all_pages.recipe \
  --output-dir ./screenshots
```

## Recipe file format

One command per line. Lines starting with `#` are comments. Blank lines are ignored.

```
# Example recipe
ACTIVATE
WAIT 1
RESIZE 1100 720
SIDEBAR Activity
WAIT 1.5
SCREENSHOT activity.png
```

## Full command reference

| Command | Arguments | Description |
|---------|-----------|-------------|
| `ACTIVATE` | — | Bring app to foreground |
| `LAUNCH` | `<path_or_bundle_id>` | Open app by path or bundle ID |
| `QUIT` | — | Gracefully quit the app |
| `KILL` | — | Force kill the app |
| `RESIZE` | `<width> <height>` | Resize frontmost window |
| `MOVE` | `<x> <y>` | Move window to screen position |
| `FULLSCREEN` | — | Toggle fullscreen mode |
| `WAIT` | `<seconds>` | Sleep; supports decimals (e.g. `0.5`) |
| `CLICK` | `<x> <y>` | Click at coordinates relative to window |
| `RIGHT_CLICK` | `<x> <y>` | Right-click at coordinates |
| `DOUBLE_CLICK` | `<x> <y>` | Double-click at coordinates |
| `TYPE` | `<text>` | Type text via keystroke |
| `KEY` | `<key> [modifiers...]` | Press key combo (e.g. `KEY w command`, `KEY f command shift`) |
| `SCROLL` | `<up\|down\|left\|right> <amount>` | Scroll by amount |
| `SIDEBAR` | `<item_name>` | Click sidebar item by name (searches outline views) |
| `MENU` | `<menu_name> <item_name>` | Click menu bar item |
| `BUTTON` | `<button_name>` | Click button by title or description |
| `TAB` | `<tab_name>` | Click tab by name |
| `CHECKBOX` | `<name> on\|off` | Toggle checkbox |
| `TEXTFIELD` | `<name_or_index> <value>` | Set text field value |
| `POPUP` | `<name> <value>` | Select from popup/dropdown |
| `TOOLBAR` | `<item_name>` | Click toolbar item |
| `SCREENSHOT` | `[filename]` | Capture app window (auto-names if omitted) |
| `SCREENSHOT_FULL` | `[filename]` | Capture entire screen |
| `SCREENSHOT_REGION` | `<x> <y> <w> <h> [filename]` | Capture screen region |
| `DARK_MODE` | `on\|off` | Toggle system dark mode |
| `SET_APPEARANCE` | `light\|dark\|auto` | Set system appearance |

**KEY modifiers:** `command` (or `cmd`), `shift`, `option` (or `alt`), `control` (or `ctrl`)

**Special key names:** `return`, `tab`, `escape`, `delete`, `space`, `up`, `down`, `left`, `right`, `f1`–`f12`

## Interactive usage (stdin)

```bash
bash /Users/linhan/.claude/skills/mac-screenshot/scripts/mac_screenshot.sh --app-name "Safari" <<'EOF'
ACTIVATE
WAIT 1
SCREENSHOT safari.png
EOF
```

## Parameters

```
--app-name <name>     Required. Process name as shown in Activity Monitor
--recipe <file>       Recipe file path. Omit to read from stdin.
--output-dir <dir>    Output directory. Default: ./screenshots
--prefix <prefix>     Auto-screenshot prefix. Default: "screen"
```

## Tips

- **Accessibility permissions**: System Preferences → Privacy & Security → Accessibility — grant Terminal (or the calling app) access
- **Timing**: Add `WAIT` before screenshots to allow animations to settle; `WAIT 1.5` is usually safe for sidebar transitions
- **Sidebar patterns**: The script uses `select row` (not `click row`) which properly triggers SwiftUI `List(selection:)` bindings. It tries four outline hierarchy patterns. If `SIDEBAR` fails, use `CLICK <x> <y>` with pixel coordinates instead
- **Localization**: `SIDEBAR` matches by displayed text, which depends on system locale. Use the actual displayed label (e.g. `SIDEBAR 活动` for Chinese, `SIDEBAR Activity` for English)
- **CGWindowID capture**: `SCREENSHOT` uses Quartz CGWindowID via Python3 for reliable window-only capture (no desktop clutter). Python3 with PyObjC must be available (`pip3 install pyobjc-framework-Quartz`)
- **Auto-naming**: `SCREENSHOT` without a filename produces `screen_01.png`, `screen_02.png`, etc. (or with custom `--prefix`)

## Example recipes

- `scripts/examples/pervius_all_pages.recipe` — capture all Pervius sidebar pages in light and dark mode
- `scripts/examples/safari_demo.recipe` — demonstrate general app automation with Safari
