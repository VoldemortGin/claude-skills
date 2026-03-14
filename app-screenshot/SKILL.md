---
name: app-screenshot
description: >
  Capture App Store-ready screenshots of a macOS app at exact required dimensions.
  Use when you need to: (1) Take App Store submission screenshots of a macOS app,
  (2) Resize captures to Apple's required pixel dimensions (2880x1800, 2560x1600, 1440x900, 1280x800),
  (3) Capture a specific app window without desktop clutter.
  Triggers: app store screenshot, submission screenshot, mac app screenshot, resize screenshot,
  App Store截图, 应用截图, 上架截图, 截图调整尺寸
allowed-tools: Bash, Read, Write
---

# macOS App Store Screenshot Capture

Capture and resize macOS app screenshots to Apple's required App Store dimensions.

## App Store Required Dimensions (Mac)

| Size | Use |
|------|-----|
| 2880 x 1800 | Required — 15" MacBook Pro (Retina) |
| 2560 x 1600 | Required — 13" MacBook Pro (Retina) |
| 1440 x 900  | Optional — 15" MacBook Pro (non-Retina) |
| 1280 x 800  | Optional — 13" MacBook Pro (non-Retina) |

Apple requires at least one 2880x1800 screenshot. Submit all four for maximum coverage.

## Key Technical Facts

- **SwiftUI apps are not scriptable via AppleScript/System Events** — use Quartz CGWindowListCopyWindowInfo via Python instead.
- **Retina displays produce @2x screenshots** — a window sized 1440x900pt produces a 2880x1800px PNG automatically. Size the window to 1440x900pt, screenshot it, and you already have the 2880x1800 asset.
- Use `screencapture -l <windowID>` to capture a specific window by its CGWindowID (no desktop clutter, no shadows by default with `-o`).
- PIL/Pillow `Image.LANCZOS` resampling gives the best quality when resizing down.

## Step-by-Step Workflow

### Step 1 — Find the window ID

```python
#!/usr/bin/env python3
# find_window.py — print CGWindowID for a named app
import Quartz

APP_NAME = "YourAppName"  # match Activity Monitor process name

windows = Quartz.CGWindowListCopyWindowInfo(
    Quartz.kCGWindowListOptionOnScreenOnly,
    Quartz.kCGNullWindowID,
)
for w in windows:
    if (
        w.get("kCGWindowOwnerName") == APP_NAME
        and w.get("kCGWindowLayer", 99) == 0
        and w.get("kCGWindowBounds", {}).get("Height", 0) > 100
    ):
        print(w["kCGWindowNumber"])
        break
```

Run it:

```bash
pip3 install pyobjc-framework-Quartz   # one-time setup
python3 find_window.py
# → 1234
```

### Step 2 — Resize the app window to 1440x900pt

Use the existing `mac-screenshot` skill's RESIZE command, or do it via AppleScript on scriptable apps:

```bash
# Via mac-screenshot skill (works for any app):
bash /Users/linhan/.claude/skills/mac-screenshot/scripts/mac_screenshot.sh \
  --app-name "YourAppName" \
  --output-dir ./screenshots <<'EOF'
ACTIVATE
WAIT 0.5
RESIZE 1440 900
WAIT 1
EOF
```

Or inline AppleScript (only for AppleScript-scriptable apps):

```bash
osascript -e 'tell application "YourAppName" to set bounds of front window to {0, 0, 1440, 900}'
```

### Step 3 — Capture the window

```bash
WINDOW_ID=1234   # from Step 1
screencapture -l "$WINDOW_ID" -o ./screenshots/raw.png
# -o removes the window shadow
```

The resulting `raw.png` will be 2880x1800px on a Retina display (the 1440x900pt window at @2x).

### Step 4 — Resize to all required dimensions

```python
#!/usr/bin/env python3
# resize_appstore.py — produce all App Store screenshot sizes from one raw capture
from pathlib import Path
from PIL import Image

RAW = Path("./screenshots/raw.png")
OUT = Path("./screenshots")

SIZES = {
    "2880x1800": (2880, 1800),
    "2560x1600": (2560, 1600),
    "1440x900":  (1440,  900),
    "1280x800":  (1280,  800),
}

img = Image.open(RAW)
print(f"Source: {img.size}")

for name, (w, h) in SIZES.items():
    resized = img.resize((w, h), Image.LANCZOS)
    out_path = OUT / f"screenshot_{name}.png"
    resized.save(out_path, "PNG")
    print(f"Saved {out_path}  ({w}x{h})")
```

```bash
pip3 install Pillow   # one-time setup
python3 resize_appstore.py
```

## All-in-one Script

```bash
#!/usr/bin/env bash
# appstore_screenshots.sh <AppName> <OutputDir>
# Usage: bash appstore_screenshots.sh "Claustra" ./screenshots

APP_NAME="${1:?Usage: $0 <AppName> <OutputDir>}"
OUT_DIR="${2:-./screenshots}"
mkdir -p "$OUT_DIR"

# 1. Resize window to 1440x900pt via mac-screenshot skill
bash /Users/linhan/.claude/skills/mac-screenshot/scripts/mac_screenshot.sh \
  --app-name "$APP_NAME" --output-dir "$OUT_DIR" <<EOF
ACTIVATE
WAIT 0.5
RESIZE 1440 900
WAIT 1
EOF

# 2. Find CGWindowID
WINDOW_ID=$(python3 - <<PYEOF
import Quartz
windows = Quartz.CGWindowListCopyWindowInfo(
    Quartz.kCGWindowListOptionOnScreenOnly, Quartz.kCGNullWindowID)
for w in windows:
    if (w.get('kCGWindowOwnerName') == '$APP_NAME'
            and w.get('kCGWindowLayer', 99) == 0
            and w.get('kCGWindowBounds', {}).get('Height', 0) > 100):
        print(w['kCGWindowNumber'])
        break
PYEOF
)

if [ -z "$WINDOW_ID" ]; then
  echo "Error: window not found for '$APP_NAME'" >&2
  exit 1
fi
echo "Window ID: $WINDOW_ID"

# 3. Capture
RAW="$OUT_DIR/raw.png"
screencapture -l "$WINDOW_ID" -o "$RAW"
echo "Captured: $RAW  ($(python3 -c "from PIL import Image; img=Image.open('$RAW'); print('%dx%d'%img.size)"))"

# 4. Resize to all App Store sizes
python3 - <<PYEOF
from pathlib import Path
from PIL import Image

img = Image.open("$RAW")
out = Path("$OUT_DIR")
for name, (w, h) in {"2880x1800":(2880,1800),"2560x1600":(2560,1600),"1440x900":(1440,900),"1280x800":(1280,800)}.items():
    p = out / f"screenshot_{name}.png"
    img.resize((w,h), Image.LANCZOS).save(p, "PNG")
    print(f"Saved {p}")
PYEOF
```

Run it:

```bash
bash appstore_screenshots.sh "Claustra" ./screenshots
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `WINDOW_ID` is empty | App must be visible on screen (not minimised). Check the app name matches `kCGWindowOwnerName` exactly (use Activity Monitor). |
| Raw PNG is 1440x900 (not 2880x1800) | Display is not Retina. Either use an external Retina display or start from a higher-res raw and skip the @2x assumption. |
| `screencapture` produces black image | Grant Screen Recording permission: System Settings → Privacy & Security → Screen Recording → enable Terminal (or iTerm2). |
| PyObjC not found | `pip3 install pyobjc-framework-Quartz` |
| Pillow not found | `pip3 install Pillow` |
| Window has wrong size | Use `RESIZE` before capturing. The mac-screenshot skill's RESIZE uses AppleScript `set size`; verify with Activity Monitor. |
| Multiple windows match | The filter picks the first layer-0 window taller than 100px. Open only one window of the app, or tighten the filter with `kCGWindowBounds` width/height checks. |
