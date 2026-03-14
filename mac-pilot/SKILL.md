# mac-pilot

## Metadata

**Triggers**: mac pilot, UI interaction, click app, navigate app, app automation, 应用交互, 视觉自动化, 点击应用, 界面导航

**Description**: A vision-driven macOS UI automation toolkit. Unlike recipe-based tools, this skill enables Claude Code to autonomously interact with ANY macOS app by using a "screenshot → analyze → act → repeat" loop. Designed for apps where Accessibility API doesn't work well (WeChat, Electron apps, games, etc.).

**Script**: `~/.claude/skills/mac-pilot/scripts/mac_pilot.py`

---

## Core Workflow

The methodology is a perception-action loop. Never assume — always verify with a screenshot before and after acting.

### Step 1: Activate the target app
```bash
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py activate "AppName"
```
This uses `open -a "AppName"` (reliable across Spaces) and waits until the app is frontmost. Returns window info as JSON.

### Step 2: Get window ID
```bash
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py windows "AppName"
```
Lists all windows (ID, name, bounds). Filter for the main window (largest, or by title). Use the `kCGWindowNumber` as the windowID.

### Step 3: Take a screenshot of the window
```bash
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py screenshot <windowID> /tmp/mac_pilot_shot.png
```
Always saves to a predictable path. On Retina displays, the image is 2x the logical window size.

### Step 4: Read and analyze the screenshot
Use the Claude Code `Read` tool to load `/tmp/mac_pilot_shot.png` into context. Visually identify the element you need to interact with. Note its approximate pixel coordinates in the image.

### Step 5: Convert image coordinates to screen coordinates
```bash
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py image-to-screen <windowID> <image_x> <image_y>
```
This handles the Retina 2x scaling and window position offset. Returns `screen_x screen_y`.

### Step 6: Click or interact
```bash
# Left click
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py click <screen_x> <screen_y>

# Double click
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py doubleclick <screen_x> <screen_y>

# Right click
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py rightclick <screen_x> <screen_y>

# Type text (supports CJK and all Unicode)
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py paste "你好世界 Hello"

# Send a key
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py key return
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py key escape
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py key v command
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py key a command
```

### Step 7: Verify with another screenshot
Always re-screenshot after acting to confirm the action succeeded. If not, analyze and retry.

---

## All Subcommands Reference

| Command | Description |
|---|---|
| `activate "AppName"` | Bring app to front using `open -a`, wait until frontmost |
| `windows "AppName"` | List all windows with ID, title, bounds (JSON) |
| `screenshot <windowID> [path]` | Capture specific window to file |
| `click <x> <y>` | Left click at screen coordinates (CGEvent) |
| `doubleclick <x> <y>` | Double click at screen coordinates |
| `rightclick <x> <y>` | Right click at screen coordinates |
| `paste "text"` | pbcopy + Cmd+V (Unicode safe, works with CJK) |
| `key <name> [mod...]` | Send key combo via CGEvent |
| `find-text <img> <x> <y> <w> <h>` | Find text band positions in image region (JSON) |
| `image-to-screen <windowID> <ix> <iy>` | Convert image pixels to screen coords |
| `display-info` | List all displays with origin, size, scale factor |

---

## Key Lessons Learned

### App Activation
- `tell application "X" to activate` **often fails silently across Spaces** — use `open -a "X"` instead.
- Always wait for the app to actually become frontmost before taking a screenshot.

### Text Input
- AppleScript `keystroke` **cannot input CJK characters** (Chinese, Japanese, Korean).
- The `paste` command uses `pbcopy` + Cmd+V which works for ALL Unicode text.
- Always click the target input field first, then use `paste`.

### Mouse Clicks
- AppleScript `click at {x,y}` is **unreliable in multi-display setups**.
- Always use CGEvent-based clicks (the `click`/`doubleclick`/`rightclick` commands).
- CGEvent uses the global coordinate system (same as NSScreen coordinates).

### Screenshots and Coordinates
- `screencapture -l<windowID>` always captures at **2x resolution on Retina displays**.
- An image pixel at (px, py) corresponds to screen coordinate: `screen = window_origin + px/scale`.
- Use `image-to-screen` to handle this automatically.
- The window position from Quartz uses the **global coordinate system** where (0,0) is the top-left of the primary display.

### List Items and Dynamic UIs
- After clicking a list item, the list **may reorder** — always re-screenshot before the next action.
- Don't estimate coordinates from screenshots by guessing — use `find-text` or pixel analysis for precision.

### Accessibility-Poor Apps
- WeChat, many Electron apps, and games expose **almost no Accessibility elements**.
- The vision-based approach (screenshot → analyze → CGEvent click) is the only reliable method.
- For these apps, never rely on `osascript`/AXUIElement-based automation.

### Display Scale Factor
- `display-info` shows the scale factor for each display (1.0 for non-Retina, 2.0 for most Retina).
- All `click` coordinates must be in **logical (points) space**, not pixel space.
- The `image-to-screen` command handles this conversion automatically.

---

## Example: Automate WeChat

```bash
# 1. Activate WeChat
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py activate "WeChat"

# 2. Find the main window
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py windows "WeChat"
# Output: [{"id": 1234, "title": "", "x": 200, "y": 100, "width": 800, "height": 600}]

# 3. Screenshot the window
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py screenshot 1234 /tmp/wechat.png

# 4. Read /tmp/wechat.png with the Read tool, identify the search box at ~(100, 60) in image coords

# 5. Convert to screen coordinates
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py image-to-screen 1234 100 60
# Output: screen_x=250 screen_y=130

# 6. Click the search box
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py click 250 130

# 7. Type search text
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py paste "张三"

# 8. Screenshot again to verify results appeared
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py screenshot 1234 /tmp/wechat_results.png
# Read the new screenshot, find the contact row...
```

---

## Example: Find Text Position in Screenshot

When you need to click a specific text label but aren't sure of exact coordinates:

```bash
# Search for dark text pixels in the left sidebar region (x=0, y=100, w=200, h=500)
python3 ~/.claude/skills/mac-pilot/scripts/mac_pilot.py find-text /tmp/wechat.png 0 100 200 500
# Output: [{"start_y": 140, "end_y": 158, "center_y": 149, "screen_y": 172}, ...]
# Each entry is a horizontal text band. Use screen_y to click.
```

---

## Troubleshooting

**App doesn't come to front**: Try `activate` twice. Some sandboxed apps need a moment.

**Click lands in wrong place**: Re-run `display-info` and `windows` to get fresh coordinates. Window may have moved.

**Text not typed**: Make sure you clicked the input field first. Check with a screenshot.

**Screenshot is blank/black**: The window may be minimized or behind another window. Use `activate` first.

**`find-text` returns nothing**: The text may use anti-aliasing with light pixels. Lower the darkness threshold in the script or use visual inspection instead.

**PyObjC not found**: It's pre-installed on macOS. If missing: `pip3 install pyobjc-framework-Quartz`.
