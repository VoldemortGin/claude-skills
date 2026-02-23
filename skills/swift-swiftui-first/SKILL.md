---
name: swift-swiftui-first
description: "SwiftUI-first development strategy with UIKit fallback decisions. Keywords: SwiftUI, UIKit, should I use, UIViewRepresentable, UIViewControllerRepresentable, AppKit, NSViewRepresentable, 用SwiftUI还是UIKit, SwiftUI优先, 界面框架选择"
user-invocable: false
---

# SwiftUI-First Development Strategy

## Core Principle
**SwiftUI first, UIKit/AppKit as fallback.** Always start with SwiftUI. Only drop to UIKit when SwiftUI genuinely cannot do it.

## Decision Flow

```
Need UI feature
  → SwiftUI has native API? → YES → Use SwiftUI ✅
  → SwiftUI lacks it?
      → Can wrap with UIViewRepresentable? → YES → Wrap it ✅
      → Too complex to wrap? → Use UIKit/AppKit screen, embed SwiftUI via UIHostingController ✅
```

## SwiftUI vs UIKit Capability Matrix

### ✅ Use SwiftUI Directly
| Feature | SwiftUI API | Min Version |
|---------|-------------|-------------|
| Lists & grids | `List`, `LazyVGrid`, `LazyHGrid` | iOS 14+ |
| Navigation | `NavigationStack`, `NavigationSplitView` | iOS 16+ |
| Sheets & alerts | `.sheet`, `.alert`, `.confirmationDialog` | iOS 15+ |
| Charts | `Charts` framework | iOS 16+ |
| Maps | `Map` (MapKit SwiftUI) | iOS 17+ |
| Forms & pickers | `Form`, `Picker`, `DatePicker` | iOS 13+ |
| Scroll views | `ScrollView`, `ScrollViewReader` | iOS 14+ |
| Search | `.searchable` | iOS 15+ |
| Photo picker | `PhotosPicker` | iOS 16+ |
| ShareLink | `ShareLink` | iOS 16+ |
| Tables (macOS) | `Table` | macOS 12+ |
| TextEditor | `TextEditor` | iOS 14+ |
| Drag & Drop | `.draggable`, `.dropDestination` | iOS 16+ |

### ⚠️ Wrap with UIViewRepresentable
| Feature | Why | Wrapper Approach |
|---------|-----|-----------------|
| WKWebView | No SwiftUI equivalent | `UIViewRepresentable` |
| MKMapView (advanced) | SwiftUI `Map` limited pre-iOS 17 | `UIViewRepresentable` |
| UITextView (rich text) | `TextEditor` lacks attributed string support | `UIViewRepresentable` |
| Camera preview | AVCaptureVideoPreviewLayer | `UIViewRepresentable` |
| PDFView | No SwiftUI equivalent | `UIViewRepresentable` |
| SFSafariViewController | Browser in-app | `UIViewControllerRepresentable` |

### 🔴 Use UIKit Screen (Embed SwiftUI Back)
| Feature | Why |
|---------|-----|
| Complex collection view layouts | Compositional layout, diffable data source |
| UIPageViewController | SwiftUI `TabView(.page)` limited |
| Advanced text input (custom keyboards) | No SwiftUI support |
| UIKit-based 3rd party SDKs | Camera SDKs, AR frameworks |

## UIViewRepresentable Best Practices

```swift
struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        WKWebView()  // Create once, configure here
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Called when SwiftUI state changes - update UIKit view
        let request = URLRequest(url: url)
        webView.load(request)
    }

    // Use Coordinator for delegates
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        // Handle delegate callbacks here
    }
}
```

### Key Rules
1. **makeUIView** — called ONCE, create and do initial setup
2. **updateUIView** — called on every SwiftUI state change, update UIKit view
3. **Coordinator** — bridge for delegates/data sources, use `context.coordinator`
4. **Avoid** recreating the view in `updateUIView` — only update properties
5. **Dismantling** — use `static func dismantleUIView` for cleanup if needed

## UIHostingController — Embedding SwiftUI in UIKit

```swift
// In a UIKit ViewController
let swiftUIView = MySwiftUIView(model: viewModel)
let hostingController = UIHostingController(rootView: swiftUIView)
addChild(hostingController)
view.addSubview(hostingController.view)
hostingController.view.translatesAutoresizingMaskIntoConstraints = false
NSLayoutConstraint.activate([
    hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
    hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
    hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
])
hostingController.didMove(toParent: self)
```

## Version Availability Strategy

```swift
// Prefer @available + ViewBuilder for version branching
@ViewBuilder
var contentView: some View {
    if #available(iOS 17, macOS 14, *) {
        // Use latest API
        ContentUnavailableView("No Results", systemImage: "magnifyingglass")
    } else {
        // Fallback for older OS
        VStack {
            Image(systemName: "magnifyingglass")
            Text("No Results")
        }
    }
}
```

## Cross-Platform Notes
| Platform | UIKit Equivalent | Representable Protocol |
|----------|-----------------|----------------------|
| iOS/tvOS | UIKit | `UIViewRepresentable` / `UIViewControllerRepresentable` |
| macOS | AppKit | `NSViewRepresentable` / `NSViewControllerRepresentable` |
| watchOS | N/A | SwiftUI only (no fallback) |
| visionOS | UIKit (spatial) | `UIViewRepresentable` + RealityKit |

## Related Skills
- `swift-layout` — Layout system details
- `swift-navigation` — Navigation patterns
- `swift-multiplatform` — Cross-platform conditional compilation
