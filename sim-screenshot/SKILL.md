---
name: sim-screenshot
description: "Capture iOS/iPadOS simulator screenshot and analyze UI quality. Use when user wants to check simulator UI, verify layout, review visual appearance, or debug UI issues on iPhone/iPad simulator. Keywords: simulator, screenshot, UI check, visual review, 模拟器截图, UI检查, 界面检查, 截图分析"
allowed-tools: Bash, Read, AskUserQuestion
---

# Simulator Screenshot & UI Analysis

Capture a screenshot from the running iOS/iPadOS simulator and analyze the UI visually.

## Steps

### 1. Check running simulators

Run `xcrun simctl list devices booted` to find which simulators are currently running.

If no simulator is booted, inform the user and ask them to launch one first via Xcode (Cmd+R).

### 2. Capture screenshot

Take a screenshot from the booted simulator:

```bash
xcrun simctl io booted screenshot /tmp/sim_screenshot.png
```

If multiple simulators are booted, list them and ask the user which one to capture. Use the device UDID to target a specific one:

```bash
xcrun simctl io <UDID> screenshot /tmp/sim_screenshot.png
```

### 3. Analyze the screenshot

Use the `Read` tool to read the screenshot image file at `/tmp/sim_screenshot.png`. Since Claude Code is multimodal, reading the image will display it visually for analysis.

### 4. Provide UI analysis

After viewing the screenshot, analyze and report on:

- **Layout**: Are elements properly aligned? Any overlapping or clipping?
- **Typography**: Is text readable? Proper font sizes and hierarchy?
- **Spacing**: Consistent padding and margins?
- **Color & Contrast**: Sufficient contrast for readability? Consistent color scheme?
- **Navigation**: Are navigation elements clear and accessible?
- **Platform conventions**: Does the UI follow iOS/iPadOS Human Interface Guidelines?
- **Dark/Light mode**: If applicable, does the current mode look correct?
- **Device adaptation**: Does the layout fit the screen size properly (especially iPad vs iPhone)?

### 5. Ask about follow-up

After the analysis, ask the user if they want to:
- Capture another screen (e.g., navigate to a different view first)
- Fix any identified issues
- Compare with a different device size (e.g., switch from iPhone to iPad)

## Notes

- This skill requires a simulator to be already running with the app launched
- For SwiftUI Preview-only checks, consider using the Xcode MCP `RenderPreview` tool instead
- Screenshots are saved to `/tmp/sim_screenshot.png` and overwritten each time
