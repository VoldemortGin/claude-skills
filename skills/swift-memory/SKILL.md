---
name: swift-memory
description: "Swift memory management, ARC, and lifecycle patterns. Keywords: ARC, weak, unowned, retain cycle, memory leak, capture list, closure, deinit, autoreleasepool, 循环引用, 内存泄漏, 弱引用, 内存管理"
user-invocable: false
---

# Swift Memory Management

## Core Principle
**ARC handles most memory. Your job is to break retain cycles.** Always think about capture lists in closures.

## When to Worry About Memory

```
Value type (struct, enum)?
  → Stack allocated, no cycles possible ✅

Reference type (class) held by closure?
  → Check for retain cycle → [weak self] or [unowned self]

Delegate pattern?
  → Make delegate property weak ✅

Timer / NotificationCenter?
  → Ensure proper cleanup in deinit or use modern APIs ✅
```

## ARC Basics

```swift
class Person {
    let name: String
    var apartment: Apartment?  // Strong reference

    init(name: String) { self.name = name }
    deinit { print("\(name) deinitialized") }
}

class Apartment {
    let unit: String
    weak var tenant: Person?  // ✅ Weak — breaks retain cycle

    init(unit: String) { self.unit = unit }
}
```

## Reference Types

| Type | Zeroing? | When to Use | Crashes if nil? |
|------|----------|-------------|-----------------|
| `strong` | N/A | Default ownership | N/A |
| `weak` | Yes → nil | May outlive referent (delegates, optional refs) | No — is Optional |
| `unowned` | No | Same or shorter lifetime guaranteed | Yes — if accessed after dealloc |

## Closure Capture Lists

### [weak self] — Most Common
```swift
class ViewModel {
    var data: [Item] = []

    func loadData() {
        apiClient.fetch { [weak self] result in
            guard let self else { return }  // Modern unwrap (Swift 5.7+)
            self.data = result
        }
    }
}
```

### [unowned self] — When Lifecycle is Guaranteed
```swift
class NetworkManager {
    lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        // Manager always outlives session — safe to use unowned
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
}
```

### When Do You Need [weak self]?

| Scenario | Need [weak self]? |
|----------|-------------------|
| `.task { }` in SwiftUI | No — auto-cancelled |
| `Task { }` capturing self | Usually yes |
| Completion handler stored by self | Yes |
| `UIView.animate` completion | No — non-escaping semantically |
| `DispatchQueue.async` one-shot | Usually no — temporary |
| Timer repeating | Yes |
| NotificationCenter closure | Yes |
| Combine `.sink` stored in `cancellables` | Yes |

## Common Retain Cycle Patterns

### 1. Closure stored on self
```swift
// ❌ Retain cycle
class ViewModel {
    var onUpdate: (() -> Void)?

    func setup() {
        onUpdate = {
            self.refresh()  // self → onUpdate → self
        }
    }
}

// ✅ Fixed
func setup() {
    onUpdate = { [weak self] in
        self?.refresh()
    }
}
```

### 2. Delegate
```swift
// ❌ Strong delegate
protocol ServiceDelegate: AnyObject { }

class Service {
    var delegate: ServiceDelegate?  // ❌ Strong
}

// ✅ Weak delegate
class Service {
    weak var delegate: ServiceDelegate?  // ✅ Weak
}
```

### 3. Combine
```swift
// ❌ Retain cycle with sink
class ViewModel: ObservableObject {
    var cancellables = Set<AnyCancellable>()

    func observe() {
        publisher.sink { value in
            self.handle(value)  // ❌ self → cancellables → sink → self
        }
        .store(in: &cancellables)
    }
}

// ✅ Fixed
publisher.sink { [weak self] value in
    self?.handle(value)
}
.store(in: &cancellables)
```

## SwiftUI Memory Considerations

```swift
// ✅ SwiftUI manages view lifecycle — usually no manual cleanup needed
struct ItemView: View {
    var body: some View {
        Text("Hello")
            .task {
                // Auto-cancelled when view disappears — no leak
                await loadData()
            }
            .onDisappear {
                // Cleanup if needed
            }
    }
}

// ⚠️ @StateObject / @State with @Observable: owned by SwiftUI, released when view removed
// ⚠️ @ObservedObject / passed references: not owned, parent responsible for lifecycle
```

## Debugging Memory Issues

### Instruments
1. **Allocations** — track object lifecycle
2. **Leaks** — detect retain cycles
3. **Memory Graph Debugger** (Xcode) — visual reference graph

### Quick Debug
```swift
class MyClass {
    deinit {
        print("MyClass deallocated")  // If never printed → likely leak
    }
}
```

## Anti-Patterns
| ❌ Don't | ✅ Do |
|---------|-------|
| `[unowned self]` when unsure of lifecycle | `[weak self]` — safer |
| Forgetting capture list in stored closures | Always check escaping closures |
| Strong delegate references | `weak var delegate` |
| Retain cycle via nested closures | Capture `[weak self]` at outermost level |
| `autoreleasepool` in Swift (rare) | Only needed for tight loops creating ObjC objects |

## Related Skills
- `swift-concurrency` — Task lifecycle
- `swift-data-flow` — Ownership of state objects
- `swift-performance` — Memory profiling with Instruments
