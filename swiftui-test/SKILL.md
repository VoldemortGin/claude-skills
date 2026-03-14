---
name: swiftui-test
description: "Automated testing of macOS SwiftUI apps using osascript and System Events. Use this skill when testing SwiftUI window constraints (min/max size), UI navigation, screenshots, dark mode toggling, menu interaction, sidebar navigation, or any automated verification of a running macOS app. Keywords: swiftui test, window minimum size, window constraint, osascript, automated ui test, macOS app testing, screencapture, dark mode test, sidebar navigation."
---

# SwiftUI macOS Automated Testing

## Overview

This skill provides a bash-based test runner that builds, launches, and interacts with macOS SwiftUI apps via `osascript` / System Events. It verifies window sizing constraints, captures screenshots, navigates UI elements, and reports PASS/FAIL per test step.

The breakthrough technique: `osascript` can resize a window to an undersized value and then read back the actual resulting size — if SwiftUI's `.frame(minWidth:minHeight:)` is wired correctly, the window will be clamped and the readback will differ from the requested size.

## Quick Start

```bash
chmod +x /Users/linhan/.claude/skills/swiftui-test/scripts/swiftui_test.sh

/Users/linhan/.claude/skills/swiftui-test/scripts/swiftui_test.sh \
  --project MyApp.xcodeproj \
  --scheme MyApp \
  --app-name MyApp \
  --test-file /Users/linhan/.claude/skills/swiftui-test/scripts/example_test.txt
```

## Test File Format

One command per line. Blank lines and `#` comments are ignored.

| Command | Effect |
|---|---|
| `BUILD` | `xcodebuild clean build` for the scheme |
| `LAUNCH` | Kill any running instance, then `open` the .app |
| `KILL` | `pkill -9 -f <AppName>` |
| `WAIT <seconds>` | `sleep` |
| `WINDOW_MIN_SIZE <w> <h>` | Resize to w-200, h-200 and verify actual size >= w, h |
| `WINDOW_MAX_SIZE <w> <h>` | Resize to w+400, h+400 and verify actual size <= w, h |
| `WINDOW_RESIZE <w> <h>` | Resize and verify exact resulting size |
| `WINDOW_SIZE_GE <w> <h>` | Verify current window size >= w, h |
| `SCREENSHOT <filename>` | `screencapture -l <windowid>` to a file |
| `DARK_MODE on\|off` | Toggle system dark mode via appearance preferences |
| `CLICK_MENU <menu> <item>` | Click a menu bar item |
| `UI_EXISTS <description>` | Assert an accessibility element with that description exists |
| `SIDEBAR_SELECT <item>` | Click a row in outline 1 of scroll area 1 of splitter group 1 |

## Interactive Mode

Claude can also run individual osascript commands inline during debugging without the script:

```bash
# Get current window size
osascript -e 'tell application "System Events" to tell process "MyApp" to get size of window 1'

# Resize window
osascript -e 'tell application "System Events" to tell process "MyApp" to set size of window 1 to {600, 400}'

# Take a window screenshot
WID=$(osascript -e 'tell application "System Events" to tell process "MyApp" to get id of window 1')
screencapture -l "$WID" /tmp/window.png
```

## Troubleshooting

**"could not get window size" / empty results**
- System Preferences > Privacy & Security > Accessibility — make sure Terminal (or your terminal emulator) is checked.
- The app window must be frontmost and fully launched. Add `WAIT 3` after `LAUNCH`.

**WINDOW_MIN_SIZE passes but window is still resizable below the limit**
- SwiftUI's `.frame(minWidth:)` only constrains via `windowResizability`. You may need `.windowResizability(.contentSize)` on the `WindowGroup` in addition to the frame modifier on the root view.

**BUILD can't find the .app after building**
- The script searches `~/Library/Developer/Xcode/DerivedData` automatically. If you have multiple schemes with the same app name, make the scheme unique or set `APP_PATH` manually before calling LAUNCH.

**Sidebar navigation fails**
- The AppleScript hierarchy `outline 1 of scroll area 1 of splitter group 1` assumes a `NavigationSplitView`. If your app uses `TabView` or a custom sidebar, inspect the hierarchy with Accessibility Inspector (Xcode > Open Developer Tool) and adjust the script's `sidebar_select()` function.

**Dark mode toggle has no effect**
- The app must respond to `NSApp.effectiveAppearance` changes. SwiftUI apps do this automatically; check that you haven't hardcoded a color scheme.
