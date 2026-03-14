---
name: swift-multiplatform
description: "Cross-platform Apple development strategies. Keywords: #if os, conditional compilation, macOS, iOS, watchOS, visionOS, tvOS, canImport, targetEnvironment, platform differences, 跨平台, 多平台适配, 条件编译"
user-invocable: false
---

# Swift Multiplatform Development

## Core Principle
**Share code via SwiftUI + Swift packages. Isolate platform-specific code with conditional compilation.**

## Platform Availability

| Feature | iOS | macOS | watchOS | tvOS | visionOS |
|---------|-----|-------|---------|------|----------|
| SwiftUI | 13+ | 10.15+ | 6+ | 13+ | 1+ |
| SwiftData | 17+ | 14+ | 10+ | 17+ | 1+ |
| NavigationStack | 16+ | 13+ | 9+ | 16+ | 1+ |
| Charts | 16+ | 13+ | 9+ | 16+ | 1+ |
| @Observable | 17+ | 14+ | 10+ | 17+ | 1+ |

## Conditional Compilation

### Platform Checks
```swift
#if os(iOS)
import UIKit
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformColor = NSColor
typealias PlatformImage = NSImage
#elseif os(watchOS)
import WatchKit
#elseif os(visionOS)
import SwiftUI
import RealityKit
#endif

// Multiple platforms
#if os(iOS) || os(tvOS)
// Shared iOS/tvOS code
#endif
```

### canImport -- Safer than os()
```swift
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(WidgetKit)
import WidgetKit
// Widget support
#endif
```

### Target Environment
```swift
#if targetEnvironment(simulator)
// Simulator-only code (e.g., skip camera)
let image = UIImage(named: "test-photo")!
#else
// Real device
let image = capturePhoto()
#endif

#if targetEnvironment(macCatalyst)
// Mac Catalyst specific
#endif
```

## SwiftUI Cross-Platform Patterns

### Platform-Adaptive Views
```swift
struct SettingsView: View {
    var body: some View {
        #if os(iOS)
        NavigationStack {
            settingsForm
                .navigationTitle("Settings")
        }
        #elseif os(macOS)
        settingsForm
            .frame(width: 400, height: 500)
            .padding()
        #elseif os(watchOS)
        settingsForm
        #endif
    }

    // Shared content
    private var settingsForm: some View {
        Form {
            Section("General") {
                Toggle("Notifications", isOn: $notificationsEnabled)
            }
        }
    }
}
```

### Platform-Specific Modifiers
```swift
extension View {
    @ViewBuilder
    func platformNavigationStyle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #elseif os(macOS)
        self.frame(minWidth: 200)
        #else
        self
        #endif
    }
}
```

## App Structure

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }

        MenuBarExtra("MyApp", systemImage: "star") {
            MenuBarView()
        }
        #endif

        #if os(visionOS)
        ImmersiveSpace(id: "immersive") {
            ImmersiveView()
        }
        #endif
    }
}
```

## Platform Differences Cheat Sheet

| Concept | iOS | macOS | watchOS |
|---------|-----|-------|---------|
| Primary navigation | Tab + Stack | Sidebar + Split | Page-based |
| Selection model | Tap | Click | Tap (crown scroll) |
| Screen size | 375-430pt | 800-2560pt | 162-205pt |
| Input | Touch | Mouse + Keyboard | Digital Crown + Touch |
| Background tasks | BGTaskScheduler | Unrestricted | WKExtendedRuntimeSession |
| Notifications | UNUserNotificationCenter | Same | WKNotificationScene |

## Swift Package for Code Sharing

```swift
// Package.swift
let package = Package(
    name: "SharedKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "SharedKit", targets: ["SharedKit"]),
    ],
    targets: [
        .target(name: "SharedKit"),
        .testTarget(name: "SharedKitTests", dependencies: ["SharedKit"]),
    ]
)
```

### Code Organization
```
SharedKit/
├── Sources/SharedKit/
│   ├── Models/          <- Shared models
│   ├── Services/        <- Shared business logic
│   ├── ViewModels/      <- Shared view models
│   └── Platform/
│       ├── iOS/         <- iOS-specific
│       ├── macOS/       <- macOS-specific
│       └── watchOS/     <- watchOS-specific
```

## visionOS Specifics

```swift
#if os(visionOS)
import RealityKit

struct ImmersiveView: View {
    var body: some View {
        RealityView { content in
            let sphere = MeshResource.generateSphere(radius: 0.1)
            let model = ModelEntity(mesh: sphere)
            content.add(model)
        }
    }
}

// Window vs Volume vs Immersive Space
// WindowGroup -- 2D flat window
// WindowGroup { }.windowStyle(.volumetric) -- 3D bounded volume
// ImmersiveSpace -- Full immersive experience
#endif
```

## Anti-Patterns
| Don't | Do |
|---------|-------|
| Duplicate entire views per platform | Share view body, branch modifiers |
| `#if os` in every file | Extract platform layer |
| UIKit on macOS (Catalyst) when SwiftUI works | Native SwiftUI for macOS |
| Ignore platform conventions | Respect each platform's HIG |
| Hardcode dimensions | Use adaptive layout |

## Related Skills
- `swift-swiftui-first` -- Framework decision per platform
- `swift-layout` -- Adaptive layouts
- `swift-navigation` -- Platform-specific navigation
