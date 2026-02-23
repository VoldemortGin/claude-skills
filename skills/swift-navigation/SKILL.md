---
name: swift-navigation
description: "SwiftUI navigation patterns and routing. Keywords: NavigationStack, NavigationSplitView, NavigationPath, NavigationLink, TabView, sheet, fullScreenCover, popover, navigationDestination, 导航, 路由, 页面跳转, 模态"
user-invocable: false
---

# Swift Navigation System

## Core Principle
**Use `NavigationStack` for push navigation, `NavigationSplitView` for master-detail.** Prefer value-based navigation over view-based.

## Navigation Decision Matrix

```
Simple push stack?
  → NavigationStack ✅

Master-detail (iPad/Mac)?
  → NavigationSplitView ✅

Modal overlay?
  → .sheet (partial) / .fullScreenCover (full) ✅

Tabs?
  → TabView ✅

Alert/confirmation?
  → .alert / .confirmationDialog ✅

Popover (iPad/Mac)?
  → .popover ✅
```

## NavigationStack (iOS 16+)

### Value-Based Navigation (Recommended)
```swift
struct ContentView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List(items) { item in
                NavigationLink(value: item) {
                    ItemRow(item: item)
                }
            }
            .navigationDestination(for: Item.self) { item in
                ItemDetail(item: item)
            }
            .navigationDestination(for: Category.self) { category in
                CategoryView(category: category)
            }
        }
    }

    // Programmatic navigation
    func navigateToItem(_ item: Item) {
        path.append(item)
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
```

### Deep Link / Programmatic Navigation
```swift
@Observable
class Router {
    var path = NavigationPath()

    func navigate(to destination: AppDestination) {
        path.append(destination)
    }

    func popToRoot() {
        path = NavigationPath()
    }

    func pop() {
        if !path.isEmpty { path.removeLast() }
    }
}

enum AppDestination: Hashable {
    case profile(userId: String)
    case settings
    case itemDetail(Item)
}
```

## NavigationSplitView (iOS 16+)

```swift
struct SplitView: View {
    @State private var selectedCategory: Category?
    @State private var selectedItem: Item?

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(categories, selection: $selectedCategory) { category in
                Text(category.name)
            }
        } content: {
            // Content (optional — omit for 2-column)
            if let category = selectedCategory {
                List(category.items, selection: $selectedItem) { item in
                    Text(item.name)
                }
            }
        } detail: {
            // Detail
            if let item = selectedItem {
                ItemDetail(item: item)
            } else {
                ContentUnavailableView("Select an Item", systemImage: "doc")
            }
        }
        .navigationSplitViewStyle(.balanced)  // or .prominentDetail
    }
}
```

## Modal Presentations

```swift
struct ParentView: View {
    @State private var showSheet = false
    @State private var showFullScreen = false
    @State private var showAlert = false
    @State private var selectedItem: Item?

    var body: some View {
        Button("Show Sheet") { showSheet = true }

        .sheet(isPresented: $showSheet) {
            SheetView()
                .presentationDetents([.medium, .large])  // iOS 16+
                .presentationDragIndicator(.visible)
        }

        // Item-based sheet
        .sheet(item: $selectedItem) { item in
            ItemDetail(item: item)
        }

        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenView()
        }

        .alert("Delete?", isPresented: $showAlert) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This cannot be undone.")
        }
    }
}

// Dismissing from child
struct SheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button("Done") { dismiss() }
    }
}
```

## TabView

```swift
// iOS 18+ (new API)
TabView {
    Tab("Home", systemImage: "house") {
        HomeView()
    }
    Tab("Search", systemImage: "magnifyingglass") {
        SearchView()
    }
    Tab("Profile", systemImage: "person") {
        ProfileView()
    }
}

// iOS 16 (legacy)
TabView {
    HomeView()
        .tabItem { Label("Home", systemImage: "house") }
    SearchView()
        .tabItem { Label("Search", systemImage: "magnifyingglass") }
}
```

## SwiftUI vs UIKit Navigation

| Feature | SwiftUI | UIKit |
|---------|---------|-------|
| Push | `NavigationStack` + `NavigationLink` | `pushViewController` |
| Modal | `.sheet` / `.fullScreenCover` | `present(_:animated:)` |
| Tab | `TabView` | `UITabBarController` |
| Split | `NavigationSplitView` | `UISplitViewController` |
| Pop to root | `path = NavigationPath()` | `popToRootViewController` |
| Custom transition | Limited (`.transition`) | Full `UIViewControllerTransitioningDelegate` |

**Need UIKit for:** Custom interactive transitions, complex coordinator patterns, UIPageViewController.

## Anti-Patterns
| ❌ Don't | ✅ Do |
|---------|-------|
| `NavigationView` (deprecated) | `NavigationStack` (iOS 16+) |
| `NavigationLink(destination:)` view-based | `NavigationLink(value:)` value-based |
| Deep nesting NavigationStacks | Single root NavigationStack |
| Passing `dismiss` through many levels | Use Router in environment |

## Related Skills
- `swift-swiftui-first` — Framework decision
- `swift-data-flow` — State for navigation
- `swift-multiplatform` — Platform-specific navigation
