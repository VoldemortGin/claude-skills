---
name: swift-data-flow
description: "SwiftUI data flow and state management patterns. Keywords: @State, @Binding, @Observable, @Environment, @EnvironmentObject, ObservableObject, @Published, @StateObject, @ObservedObject, @AppStorage, 数据流, 状态管理, 响应式"
user-invocable: false
---

# Swift Data Flow & State Management

## Core Principle
**Use the simplest property wrapper that works.** Start with `@State`, escalate only when needed.

## Decision Matrix (iOS 17+ / @Observable World)

```
Data owned by this view only?
  → @State ✅

Data passed from parent, child needs write access?
  → @Binding ✅

Shared model object (reference type)?
  → @Observable class + pass as parameter ✅
  → Need it from environment? → @Environment ✅

Simple value from environment?
  → @Environment(\.colorScheme) ✅

Persist to UserDefaults?
  → @AppStorage ✅

Persist to SwiftData?
  → @Query ✅
```

## Modern (@Observable) vs Legacy (ObservableObject)

### ✅ Modern: @Observable (iOS 17+)
```swift
@Observable
class UserProfile {
    var name: String = ""
    var age: Int = 0
    // Automatic change tracking — no @Published needed
}

struct ProfileView: View {
    var profile: UserProfile  // Just pass it — no wrapper needed for read

    var body: some View {
        Text(profile.name)  // Automatically tracks changes
    }
}

struct EditView: View {
    @Bindable var profile: UserProfile  // @Bindable for write access ($binding)

    var body: some View {
        TextField("Name", text: $profile.name)
    }
}
```

### ⚠️ Legacy: ObservableObject (iOS 13+)
```swift
class UserProfile: ObservableObject {
    @Published var name: String = ""
    @Published var age: Int = 0
}

struct ProfileView: View {
    @StateObject var profile = UserProfile()      // Owns it
    // or
    @ObservedObject var profile: UserProfile      // Doesn't own it
    @EnvironmentObject var profile: UserProfile   // From environment
}
```

## Property Wrapper Quick Reference

| Wrapper | Ownership | Type | Use Case | Min iOS |
|---------|-----------|------|----------|---------|
| `@State` | View owns | Value type | Local view state | 13 |
| `@Binding` | Parent owns | Value type | Child write access | 13 |
| `@Observable` | Automatic | Reference type | Shared model (modern) | 17 |
| `@Bindable` | External | @Observable class | Bindings to @Observable | 17 |
| `@Environment` | System/custom | Any | Dependency injection | 13/17 |
| `@AppStorage` | UserDefaults | Value type | Simple persistence | 14 |
| `@SceneStorage` | Scene state | Value type | State restoration | 14 |
| `@Query` | SwiftData | Model array | Database queries | 17 |

### Legacy (pre-iOS 17)
| Wrapper | Ownership | Use Case |
|---------|-----------|----------|
| `@StateObject` | View owns | Create ObservableObject |
| `@ObservedObject` | Parent owns | Receive ObservableObject |
| `@EnvironmentObject` | Environment | Shared ObservableObject |

## Environment Values

```swift
// Reading built-in environment
@Environment(\.dismiss) private var dismiss
@Environment(\.colorScheme) private var colorScheme
@Environment(\.horizontalSizeClass) private var sizeClass

// Custom environment value (modern)
@Observable
class AuthManager {
    var isLoggedIn = false
}

// Inject
ContentView()
    .environment(authManager)  // iOS 17+: pass @Observable directly

// Read
@Environment(AuthManager.self) private var auth

// Legacy custom environment key
struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .default
}
extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
```

## Common Patterns

### ViewModel Pattern
```swift
@Observable
class ItemListViewModel {
    var items: [Item] = []
    var isLoading = false
    var errorMessage: String?

    func loadItems() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await api.fetchItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ItemListView: View {
    @State private var viewModel = ItemListViewModel()

    var body: some View {
        List(viewModel.items) { item in
            ItemRow(item: item)
        }
        .task { await viewModel.loadItems() }
    }
}
```

## Anti-Patterns
| ❌ Don't | ✅ Do |
|---------|-------|
| `@ObservedObject var vm = ViewModel()` | `@StateObject var vm = ViewModel()` (pre-17) |
| Passing model through 5 levels | Use `@Environment` |
| `@State` for reference types | `@State` for value types only |
| `@Published` with `@Observable` | `@Observable` tracks automatically |
| Giant god-object ViewModel | Split into focused models |

## Related Skills
- `swift-swiftui-first` — When to use SwiftUI vs UIKit
- `swift-concurrency` — Async data loading patterns
- `swift-persistence` — SwiftData and @Query
