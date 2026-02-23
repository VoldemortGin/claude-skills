---
name: swift-concurrency
description: "Swift structured concurrency and async/await patterns. Keywords: async, await, actor, Task, TaskGroup, Sendable, MainActor, AsyncSequence, continuation, structured concurrency, 并发, 异步, 线程安全, Actor模型"
user-invocable: false
---

# Swift Concurrency

## Core Principle
**Use structured concurrency.** Prefer `async/await` over GCD/completion handlers. Use actors for thread-safe mutable state.

## Decision Flow

```
Need async operation?
  → async/await ✅

Need parallel execution?
  → TaskGroup ✅

Need thread-safe mutable state?
  → actor ✅

Need to update UI?
  → @MainActor ✅

Bridging callback-based API?
  → withCheckedContinuation / withCheckedThrowingContinuation ✅
```

## async/await Basics

```swift
// Declaring async function
func fetchUser(id: String) async throws -> User {
    let url = URL(string: "https://api.example.com/users/\(id)")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}

// Calling
let user = try await fetchUser(id: "123")

// In SwiftUI
struct UserView: View {
    @State private var user: User?

    var body: some View {
        Text(user?.name ?? "Loading...")
            .task {  // Preferred: auto-cancelled when view disappears
                user = try? await fetchUser(id: "123")
            }
    }
}
```

## Task

```swift
// Unstructured task — fire and forget
Task {
    await doSomething()
}

// Detached task — no inherited context (rare)
Task.detached(priority: .background) {
    await heavyComputation()
}

// Cancellation
let task = Task {
    for item in items {
        try Task.checkCancellation()  // Throw if cancelled
        await process(item)
    }
}
task.cancel()  // Request cancellation
```

## TaskGroup — Parallel Execution

```swift
// Parallel fetch with TaskGroup
func fetchAllUsers(ids: [String]) async throws -> [User] {
    try await withThrowingTaskGroup(of: User.self) { group in
        for id in ids {
            group.addTask {
                try await fetchUser(id: id)
            }
        }

        var users: [User] = []
        for try await user in group {
            users.append(user)
        }
        return users
    }
}

// Limiting concurrency (manual)
func downloadImages(urls: [URL]) async throws -> [UIImage] {
    try await withThrowingTaskGroup(of: UIImage.self) { group in
        let maxConcurrency = 4
        var results: [UIImage] = []
        var index = 0

        // Start initial batch
        for _ in 0..<min(maxConcurrency, urls.count) {
            let url = urls[index]
            group.addTask { try await downloadImage(from: url) }
            index += 1
        }

        // As each completes, start next
        for try await image in group {
            results.append(image)
            if index < urls.count {
                let url = urls[index]
                group.addTask { try await downloadImage(from: url) }
                index += 1
            }
        }
        return results
    }
}
```

## Actor — Thread-Safe State

```swift
actor ImageCache {
    private var cache: [URL: UIImage] = [:]

    func image(for url: URL) -> UIImage? {
        cache[url]
    }

    func store(_ image: UIImage, for url: URL) {
        cache[url] = image
    }
}

// Usage — must await actor methods
let cache = ImageCache()
await cache.store(image, for: url)
let cached = await cache.image(for: url)
```

## @MainActor

```swift
// Entire class on main actor (common for ViewModels)
@MainActor
@Observable
class ItemListViewModel {
    var items: [Item] = []
    var isLoading = false

    func loadItems() async {
        isLoading = true  // Safe: we're on MainActor
        let fetched = await api.fetchItems()  // Suspends, may hop off main
        items = fetched  // Back on MainActor automatically
        isLoading = false
    }
}

// Single function on MainActor
func updateUI() async {
    let data = await fetchData()  // Background
    await MainActor.run {
        self.label.text = data.title  // Main thread
    }
}

// Nonisolated escape hatch
@MainActor
class ViewModel {
    nonisolated func computeHash() -> String {
        // Can run on any thread — no actor-isolated state access
        return SHA256.hash(data: someData).description
    }
}
```

## Sendable

```swift
// Value types are implicitly Sendable
struct Point: Sendable {
    let x: Double
    let y: Double
}

// Classes must be final + immutable or use @unchecked Sendable
final class Config: Sendable {
    let apiKey: String  // Only let properties
    init(apiKey: String) { self.apiKey = apiKey }
}

// @unchecked when you guarantee safety yourself
final class ThreadSafeCache: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Any] = [:]

    func get(_ key: String) -> Any? {
        lock.withLock { storage[key] }
    }
}
```

## AsyncSequence

```swift
// Consuming
for await line in url.lines {
    print(line)
}

// Custom AsyncStream
func notifications() -> AsyncStream<Notification> {
    AsyncStream { continuation in
        let observer = NotificationCenter.default.addObserver(
            forName: .myNotification, object: nil, queue: nil
        ) { notification in
            continuation.yield(notification)
        }
        continuation.onTermination = { _ in
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
```

## Bridging Completion Handlers

```swift
func fetchLegacy() async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
        legacyFetch { result in
            switch result {
            case .success(let data):
                continuation.resume(returning: data)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}
// ⚠️ continuation.resume must be called EXACTLY once
```

## SwiftUI Integration

| Pattern | API |
|---------|-----|
| Load on appear | `.task { await ... }` |
| Load with ID change | `.task(id: itemId) { await ... }` |
| Refresh | `.refreshable { await ... }` |
| Button action | `Task { await ... }` in action closure |

## Anti-Patterns
| ❌ Don't | ✅ Do |
|---------|-------|
| `DispatchQueue.main.async` | `@MainActor` or `MainActor.run` |
| `DispatchQueue.global()` | `Task { }` or `Task.detached` |
| Nested completion handlers | `async/await` chain |
| Unstructured `Task` everywhere | `TaskGroup` for parallel work |
| `Task { await ... }` in `.task` | Just use `await` directly in `.task` |

## Related Skills
- `swift-data-flow` — Async data loading in SwiftUI
- `swift-networking` — Async networking
- `swift-memory` — Task lifecycle and memory
