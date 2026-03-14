#!/usr/bin/env python3
"""
mac_pilot.py — Vision-driven macOS UI automation primitives.

Uses PyObjC (Quartz) which is pre-installed on macOS. No pip required.
If PIL/Pillow is available, it will be used for find-text; otherwise falls
back to Quartz CGImage pixel reading.

Usage:
    python3 mac_pilot.py <subcommand> [args...]

Run with --help for full usage.
"""

import argparse
import json
import subprocess
import sys
import time

try:
    import Quartz
    from Quartz import (
        CGWindowListCopyWindowInfo,
        kCGWindowListOptionAll,
        kCGWindowListOptionOnScreenOnly,
        kCGWindowListExcludeDesktopElements,
        kCGNullWindowID,
        CGEventCreateMouseEvent,
        CGEventPost,
        kCGHIDEventTap,
        kCGEventLeftMouseDown,
        kCGEventLeftMouseUp,
        kCGEventRightMouseDown,
        kCGEventRightMouseUp,
        CGEventCreateKeyboardEvent,
        CGEventSetIntegerValueField,
        kCGKeyboardEventAutorepeat,
        CGEventSetFlags,
        CGGetActiveDisplayList,
        CGDisplayBounds,
        CGDisplayCopyDisplayMode,
        CGDisplayModeGetPixelWidth,
        CGDisplayModeGetWidth,
        CGMainDisplayID,
        CGRectMake,
        CGEventMaskBit,
    )
    from Quartz.CoreGraphics import (
        kCGEventFlagMaskCommand,
        kCGEventFlagMaskShift,
        kCGEventFlagMaskAlternate,
        kCGEventFlagMaskControl,
        kCGMouseButtonLeft,
        kCGMouseButtonRight,
    )
except ImportError:
    print("ERROR: PyObjC/Quartz not available. Install with: pip3 install pyobjc-framework-Quartz", file=sys.stderr)
    sys.exit(1)

try:
    from PIL import Image
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False


# ---------------------------------------------------------------------------
# Key name → virtual key code mapping (US keyboard layout)
# ---------------------------------------------------------------------------
KEY_CODES = {
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
    "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
    "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
    "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
    "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
    "return": 36, "enter": 36,
    "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42,
    ",": 43, "/": 44, "n": 45, "m": 46, ".": 47,
    "tab": 48,
    "space": 49,
    "`": 50,
    "delete": 51, "backspace": 51,
    "escape": 53, "esc": 53,
    "command": 55, "cmd": 55,
    "shift": 56,
    "capslock": 57,
    "option": 58, "alt": 58,
    "control": 59, "ctrl": 59,
    "right_shift": 60,
    "right_option": 61,
    "right_control": 62,
    "fn": 63,
    "f17": 64,
    "keypad_decimal": 65,
    "keypad_multiply": 67,
    "keypad_plus": 69,
    "keypad_clear": 71,
    "keypad_divide": 75,
    "keypad_enter": 76,
    "keypad_minus": 78,
    "keypad_equals": 81,
    "keypad_0": 82, "keypad_1": 83, "keypad_2": 84, "keypad_3": 85,
    "keypad_4": 86, "keypad_5": 87, "keypad_6": 88, "keypad_7": 89,
    "keypad_8": 91, "keypad_9": 92,
    "f5": 96, "f6": 97, "f7": 98, "f3": 99, "f8": 100, "f9": 101,
    "f11": 103, "f13": 105, "f16": 106, "f14": 107, "f10": 109,
    "f12": 111, "f15": 113,
    "help": 114,
    "home": 115,
    "pageup": 116,
    "forward_delete": 117,
    "f4": 118, "end": 119, "f2": 120, "pagedown": 121, "f1": 122,
    "left": 123, "right": 124, "down": 125, "up": 126,
}

MODIFIER_FLAGS = {
    "command": kCGEventFlagMaskCommand,
    "cmd": kCGEventFlagMaskCommand,
    "shift": kCGEventFlagMaskShift,
    "option": kCGEventFlagMaskAlternate,
    "alt": kCGEventFlagMaskAlternate,
    "control": kCGEventFlagMaskControl,
    "ctrl": kCGEventFlagMaskControl,
}


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _get_all_windows(app_name: str) -> list[dict]:
    """Return list of window dicts for the given app name (searches ALL windows)."""
    window_list = CGWindowListCopyWindowInfo(
        kCGWindowListOptionAll | kCGWindowListExcludeDesktopElements,
        kCGNullWindowID,
    )
    results = []
    for w in window_list:
        owner = w.get("kCGWindowOwnerName", "")
        if owner.lower() != app_name.lower():
            continue
        bounds = w.get("kCGWindowBounds", {})
        h = bounds.get("Height", 0)
        if h < 50:
            continue  # skip menu bar items and tiny helper windows
        results.append({
            "id": w.get("kCGWindowNumber", -1),
            "title": w.get("kCGWindowName", ""),
            "x": int(bounds.get("X", 0)),
            "y": int(bounds.get("Y", 0)),
            "width": int(bounds.get("Width", 0)),
            "height": int(h),
            "layer": w.get("kCGWindowLayer", 0),
            "on_screen": bool(w.get("kCGWindowIsOnscreen", False)),
        })
    return results


def _get_window_by_id(window_id: int) -> dict | None:
    """Return window dict for specific window ID."""
    window_list = CGWindowListCopyWindowInfo(
        kCGWindowListOptionAll | kCGWindowListExcludeDesktopElements,
        kCGNullWindowID,
    )
    for w in window_list:
        if w.get("kCGWindowNumber", -1) == window_id:
            bounds = w.get("kCGWindowBounds", {})
            return {
                "id": window_id,
                "title": w.get("kCGWindowName", ""),
                "x": int(bounds.get("X", 0)),
                "y": int(bounds.get("Y", 0)),
                "width": int(bounds.get("Width", 0)),
                "height": int(bounds.get("Height", 0)),
            }
    return None


def _get_display_scale(screen_x: int, screen_y: int) -> float:
    """Return the scale factor of the display that contains the given screen point."""
    err, display_ids, n = Quartz.CGGetActiveDisplayList(32, None, None)
    if err != 0:
        return 2.0  # safe default for Retina

    for disp_id in display_ids[:n]:
        bounds = Quartz.CGDisplayBounds(disp_id)
        bx = bounds.origin.x
        by = bounds.origin.y
        bw = bounds.size.width
        bh = bounds.size.height
        if bx <= screen_x < bx + bw and by <= screen_y < by + bh:
            mode = Quartz.CGDisplayCopyDisplayMode(disp_id)
            if mode:
                pixel_w = Quartz.CGDisplayModeGetPixelWidth(mode)
                logical_w = Quartz.CGDisplayModeGetWidth(mode)
                if logical_w > 0:
                    return pixel_w / logical_w
    return 2.0  # default to Retina


def _send_mouse_event(event_type_down, event_type_up, button, x: float, y: float, click_count: int = 1):
    """Send a mouse down+up event pair at the given screen coordinates."""
    point = Quartz.CGPoint(x, y)
    ev_down = Quartz.CGEventCreateMouseEvent(None, event_type_down, point, button)
    ev_up = Quartz.CGEventCreateMouseEvent(None, event_type_up, point, button)
    if click_count > 1:
        Quartz.CGEventSetIntegerValueField(ev_down, Quartz.kCGMouseEventClickState, click_count)
        Quartz.CGEventSetIntegerValueField(ev_up, Quartz.kCGMouseEventClickState, click_count)
    Quartz.CGEventPost(kCGHIDEventTap, ev_down)
    time.sleep(0.05)
    Quartz.CGEventPost(kCGHIDEventTap, ev_up)
    time.sleep(0.05)


def _send_key_event(key_code: int, flags: int = 0):
    """Send a key down+up event."""
    ev_down = Quartz.CGEventCreateKeyboardEvent(None, key_code, True)
    ev_up = Quartz.CGEventCreateKeyboardEvent(None, key_code, False)
    if flags:
        Quartz.CGEventSetFlags(ev_down, flags)
        Quartz.CGEventSetFlags(ev_up, flags)
    Quartz.CGEventPost(kCGHIDEventTap, ev_down)
    time.sleep(0.05)
    Quartz.CGEventPost(kCGHIDEventTap, ev_up)
    time.sleep(0.05)


# ---------------------------------------------------------------------------
# Subcommand implementations
# ---------------------------------------------------------------------------

def cmd_activate(args):
    app_name = args.app_name
    subprocess.run(["open", "-a", app_name], check=False)

    # Poll until app appears as frontmost / on-screen window
    deadline = time.time() + 5.0
    while time.time() < deadline:
        time.sleep(0.3)
        windows = _get_all_windows(app_name)
        on_screen = [w for w in windows if w["on_screen"]]
        if on_screen:
            print(json.dumps({"status": "ok", "app": app_name, "windows": on_screen}))
            return

    # App may be open but not reporting windows yet; return what we have
    windows = _get_all_windows(app_name)
    if windows:
        print(json.dumps({"status": "ok", "app": app_name, "windows": windows}))
    else:
        print(json.dumps({"status": "timeout", "app": app_name, "windows": []}))


def cmd_windows(args):
    app_name = args.app_name
    windows = _get_all_windows(app_name)
    print(json.dumps(windows, indent=2))


def cmd_screenshot(args):
    window_id = args.window_id
    output_path = args.output_path or "/tmp/mac_pilot_shot.png"

    result = subprocess.run(
        ["screencapture", f"-l{window_id}", "-x", output_path],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"ERROR: screencapture failed: {result.stderr}", file=sys.stderr)
        sys.exit(1)

    print(json.dumps({"status": "ok", "path": output_path, "window_id": window_id}))


def cmd_click(args):
    x, y = float(args.x), float(args.y)
    _send_mouse_event(
        kCGEventLeftMouseDown, kCGEventLeftMouseUp,
        kCGMouseButtonLeft, x, y, click_count=1,
    )
    print(json.dumps({"status": "ok", "action": "click", "x": x, "y": y}))


def cmd_doubleclick(args):
    x, y = float(args.x), float(args.y)
    # First click
    _send_mouse_event(
        kCGEventLeftMouseDown, kCGEventLeftMouseUp,
        kCGMouseButtonLeft, x, y, click_count=1,
    )
    # Second click with count=2
    _send_mouse_event(
        kCGEventLeftMouseDown, kCGEventLeftMouseUp,
        kCGMouseButtonLeft, x, y, click_count=2,
    )
    print(json.dumps({"status": "ok", "action": "doubleclick", "x": x, "y": y}))


def cmd_rightclick(args):
    x, y = float(args.x), float(args.y)
    _send_mouse_event(
        kCGEventRightMouseDown, kCGEventRightMouseUp,
        kCGMouseButtonRight, x, y, click_count=1,
    )
    print(json.dumps({"status": "ok", "action": "rightclick", "x": x, "y": y}))


def cmd_paste(args):
    text = args.text
    # Copy to clipboard
    proc = subprocess.run(["pbcopy"], input=text.encode("utf-8"), check=True)

    time.sleep(0.1)  # let clipboard settle

    # Send Cmd+V
    cmd_flag = kCGEventFlagMaskCommand
    key_v = KEY_CODES["v"]
    ev_down = Quartz.CGEventCreateKeyboardEvent(None, key_v, True)
    ev_up = Quartz.CGEventCreateKeyboardEvent(None, key_v, False)
    Quartz.CGEventSetFlags(ev_down, cmd_flag)
    Quartz.CGEventSetFlags(ev_up, cmd_flag)
    Quartz.CGEventPost(kCGHIDEventTap, ev_down)
    time.sleep(0.05)
    Quartz.CGEventPost(kCGHIDEventTap, ev_up)
    time.sleep(0.1)

    print(json.dumps({"status": "ok", "action": "paste", "text_length": len(text)}))


def cmd_key(args):
    key_name = args.key_name.lower()
    modifiers = [m.lower() for m in (args.modifiers or [])]

    if key_name not in KEY_CODES:
        print(f"ERROR: Unknown key '{key_name}'. Available keys: {', '.join(sorted(KEY_CODES.keys()))}", file=sys.stderr)
        sys.exit(1)

    key_code = KEY_CODES[key_name]
    flags = 0
    for mod in modifiers:
        if mod not in MODIFIER_FLAGS:
            print(f"ERROR: Unknown modifier '{mod}'. Available: {', '.join(MODIFIER_FLAGS.keys())}", file=sys.stderr)
            sys.exit(1)
        flags |= MODIFIER_FLAGS[mod]

    _send_key_event(key_code, flags)
    print(json.dumps({"status": "ok", "action": "key", "key": key_name, "modifiers": modifiers}))


def cmd_find_text(args):
    image_path = args.image_path
    rx, ry, rw, rh = int(args.region_x), int(args.region_y), int(args.region_w), int(args.region_h)
    darkness_threshold = 100  # R,G,B all below this = dark pixel

    if PIL_AVAILABLE:
        img = Image.open(image_path).convert("RGB")
        width, height = img.size

        # Clamp region to image bounds
        x1 = max(0, rx)
        y1 = max(0, ry)
        x2 = min(width, rx + rw)
        y2 = min(height, ry + rh)

        # For each row in the region, count dark pixels
        dark_rows = []
        for row_y in range(y1, y2):
            dark_count = 0
            for col_x in range(x1, x2):
                r, g, b = img.getpixel((col_x, row_y))
                if r < darkness_threshold and g < darkness_threshold and b < darkness_threshold:
                    dark_count += 1
            if dark_count >= 2:  # at least 2 dark pixels to count as a text row
                dark_rows.append(row_y)
    else:
        # Fallback: use Quartz CGImage
        img_ref = Quartz.CGImageSourceCreateWithURL(
            Quartz.CFURLCreateFromFileSystemRepresentation(None, image_path.encode(), len(image_path), False),
            None,
        )
        if img_ref is None:
            print(f"ERROR: Could not load image at {image_path}", file=sys.stderr)
            sys.exit(1)
        cg_img = Quartz.CGImageSourceCreateImageAtIndex(img_ref, 0, None)
        img_width = Quartz.CGImageGetWidth(cg_img)
        img_height = Quartz.CGImageGetHeight(cg_img)

        # Render to a raw bytes buffer
        color_space = Quartz.CGColorSpaceCreateDeviceRGB()
        ctx = Quartz.CGBitmapContextCreate(
            None, img_width, img_height, 8, img_width * 4,
            color_space,
            Quartz.kCGImageAlphaPremultipliedLast | Quartz.kCGBitmapByteOrder32Big,
        )
        Quartz.CGContextDrawImage(ctx, Quartz.CGRectMake(0, 0, img_width, img_height), cg_img)
        raw_data = Quartz.CGBitmapContextGetData(ctx)

        import ctypes
        buf_size = img_width * img_height * 4
        raw_bytes = (ctypes.c_uint8 * buf_size).from_address(raw_data)

        x1 = max(0, rx)
        y1 = max(0, ry)
        x2 = min(img_width, rx + rw)
        y2 = min(img_height, ry + rh)

        dark_rows = []
        for row_y in range(y1, y2):
            # CGBitmapContext stores rows bottom-to-top; flip y
            flipped_y = img_height - 1 - row_y
            dark_count = 0
            for col_x in range(x1, x2):
                idx = (flipped_y * img_width + col_x) * 4
                r = raw_bytes[idx]
                g = raw_bytes[idx + 1]
                b = raw_bytes[idx + 2]
                if r < darkness_threshold and g < darkness_threshold and b < darkness_threshold:
                    dark_count += 1
            if dark_count >= 2:
                dark_rows.append(row_y)

    # Group consecutive dark rows into text bands
    bands = []
    if dark_rows:
        band_start = dark_rows[0]
        band_end = dark_rows[0]
        for r in dark_rows[1:]:
            if r <= band_end + 3:  # allow small gaps (anti-aliasing)
                band_end = r
            else:
                bands.append((band_start, band_end))
                band_start = r
                band_end = r
        bands.append((band_start, band_end))

    # For screen_y we don't have window context here — return image coords only
    result = []
    for start_y, end_y in bands:
        center_y = (start_y + end_y) // 2
        result.append({
            "start_y": start_y,
            "end_y": end_y,
            "center_y": center_y,
            "note": "Use image-to-screen to convert to screen coordinates",
        })

    print(json.dumps(result, indent=2))


def cmd_image_to_screen(args):
    window_id = int(args.window_id)
    image_x = float(args.image_x)
    image_y = float(args.image_y)

    win = _get_window_by_id(window_id)
    if win is None:
        print(f"ERROR: Window {window_id} not found", file=sys.stderr)
        sys.exit(1)

    win_x = win["x"]
    win_y = win["y"]

    # Determine scale by checking display at window origin
    scale = _get_display_scale(win_x, win_y)
    if scale <= 0:
        scale = 2.0  # safe Retina default

    screen_x = win_x + image_x / scale
    screen_y = win_y + image_y / scale

    print(f"screen_x={int(screen_x)} screen_y={int(screen_y)}")
    # Also print JSON for programmatic use
    print(json.dumps({
        "screen_x": int(screen_x),
        "screen_y": int(screen_y),
        "window_x": win_x,
        "window_y": win_y,
        "scale": scale,
        "image_x": image_x,
        "image_y": image_y,
    }))


def cmd_display_info(args):
    err, display_ids, n = Quartz.CGGetActiveDisplayList(32, None, None)
    if err != 0:
        print(f"ERROR: CGGetActiveDisplayList returned {err}", file=sys.stderr)
        sys.exit(1)

    displays = []
    for disp_id in display_ids[:n]:
        bounds = Quartz.CGDisplayBounds(disp_id)
        mode = Quartz.CGDisplayCopyDisplayMode(disp_id)
        scale = 1.0
        if mode:
            pixel_w = Quartz.CGDisplayModeGetPixelWidth(mode)
            logical_w = Quartz.CGDisplayModeGetWidth(mode)
            if logical_w > 0:
                scale = pixel_w / logical_w
        displays.append({
            "display_id": int(disp_id),
            "is_main": bool(disp_id == Quartz.CGMainDisplayID()),
            "origin_x": int(bounds.origin.x),
            "origin_y": int(bounds.origin.y),
            "width": int(bounds.size.width),
            "height": int(bounds.size.height),
            "scale_factor": scale,
        })

    print(json.dumps(displays, indent=2))


# ---------------------------------------------------------------------------
# CLI wiring
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="mac_pilot.py",
        description="Vision-driven macOS UI automation primitives.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # activate
    p = sub.add_parser("activate", help="Bring app to front using open -a")
    p.add_argument("app_name", help="Application name (e.g. 'WeChat', 'Finder')")
    p.set_defaults(func=cmd_activate)

    # windows
    p = sub.add_parser("windows", help="List all windows for an app")
    p.add_argument("app_name", help="Application name")
    p.set_defaults(func=cmd_windows)

    # screenshot
    p = sub.add_parser("screenshot", help="Screenshot a specific window by ID")
    p.add_argument("window_id", type=int, help="Window ID (from 'windows' subcommand)")
    p.add_argument("output_path", nargs="?", default="/tmp/mac_pilot_shot.png",
                   help="Output PNG path (default: /tmp/mac_pilot_shot.png)")
    p.set_defaults(func=cmd_screenshot)

    # click
    p = sub.add_parser("click", help="Left click at screen coordinates")
    p.add_argument("x", help="Screen X coordinate (logical points)")
    p.add_argument("y", help="Screen Y coordinate (logical points)")
    p.set_defaults(func=cmd_click)

    # doubleclick
    p = sub.add_parser("doubleclick", help="Double click at screen coordinates")
    p.add_argument("x", help="Screen X coordinate")
    p.add_argument("y", help="Screen Y coordinate")
    p.set_defaults(func=cmd_doubleclick)

    # rightclick
    p = sub.add_parser("rightclick", help="Right click at screen coordinates")
    p.add_argument("x", help="Screen X coordinate")
    p.add_argument("y", help="Screen Y coordinate")
    p.set_defaults(func=cmd_rightclick)

    # paste
    p = sub.add_parser("paste", help="Paste text via pbcopy + Cmd+V (Unicode safe)")
    p.add_argument("text", help="Text to paste (supports CJK and all Unicode)")
    p.set_defaults(func=cmd_paste)

    # key
    p = sub.add_parser("key", help="Send a key press via CGEvent")
    p.add_argument("key_name", help="Key name (e.g. return, escape, v, space, up, f5)")
    p.add_argument("modifiers", nargs="*",
                   help="Optional modifiers: command, shift, option, control")
    p.set_defaults(func=cmd_key)

    # find-text
    p = sub.add_parser("find-text", help="Find text band positions in an image region")
    p.add_argument("image_path", help="Path to PNG/JPG image")
    p.add_argument("region_x", help="Region X offset in image pixels")
    p.add_argument("region_y", help="Region Y offset in image pixels")
    p.add_argument("region_w", help="Region width in image pixels")
    p.add_argument("region_h", help="Region height in image pixels")
    p.set_defaults(func=cmd_find_text)

    # image-to-screen
    p = sub.add_parser("image-to-screen", help="Convert image pixel coords to screen coords")
    p.add_argument("window_id", help="Window ID (from 'windows' subcommand)")
    p.add_argument("image_x", help="X coordinate in screenshot image (pixels)")
    p.add_argument("image_y", help="Y coordinate in screenshot image (pixels)")
    p.set_defaults(func=cmd_image_to_screen)

    # display-info
    p = sub.add_parser("display-info", help="List all displays with origin, size, scale factor")
    p.set_defaults(func=cmd_display_info)

    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
