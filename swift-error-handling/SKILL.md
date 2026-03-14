---
name: swift-error-handling
description: "Swift error handling patterns and best practices. Keywords: throws, try, catch, Result, Error protocol, do-catch, typed throws, rethrows, fatalError, precondition, 错误处理, 异常处理, 容错"
user-invocable: false
---

# Swift Error Handling

## Core Principle
**Use `throws` for recoverable errors, `fatalError`/`precondition` for programmer errors.** Be specific with error types.

## Decision Flow

```
Recoverable failure?
  → throws / Result ✅

Programmer mistake (bug)?
  → fatalError / preconditionFailure ✅

Optional absence (not error)?
  → Optional (nil) ✅

Async error?
  → async throws ✅
```

## Basic Error Handling

```swift
// Define errors
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noConnection
    case serverError(statusCode: Int)
    case decodingFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .noConnection: "No internet connection"
        case .serverError(let code): "Server error (\(code))"
        case .decodingFailed: "Failed to parse response"
        }
    }
}

// Throwing function
func fetchUser(id: String) throws -> User {
    guard let url = URL(string: "https://api.example.com/users/\(id)") else {
        throw NetworkError.invalidURL
    }
    // ...
}

// Calling
do {
    let user = try fetchUser(id: "123")
    print(user.name)
} catch let error as NetworkError {
    switch error {
    case .serverError(let code) where code == 404:
        showNotFound()
    case .noConnection:
        showOfflineMessage()
    default:
        showError(error)
    }
} catch {
    showError(error)  // Catch-all
}
```

## try Variants

| Syntax | Behavior |
|--------|----------|
| `try` | Propagates error — must be in `do-catch` or `throws` function |
| `try?` | Converts to Optional — nil on error |
| `try!` | Force unwrap — crashes on error (use sparingly) |

```swift
// try? — good for optional results
let user = try? fetchUser(id: "123")  // User? — nil if error

// try? with default
let user = (try? fetchUser(id: "123")) ?? defaultUser

// try! — only when failure is truly impossible
let regex = try! NSRegularExpression(pattern: "^[a-z]+$")
```

## Typed Throws (Swift 6.0+)

```swift
// Specify exact error type
func parse(json: Data) throws(ParseError) -> Config {
    guard let dict = try? JSONSerialization.jsonObject(with: json) else {
        throw .invalidJSON
    }
    // ...
}

// Caller knows exact error type — no casting needed
do {
    let config = try parse(json: data)
} catch .invalidJSON {
    // Direct pattern match — no `as` cast
} catch .missingKey(let key) {
    print("Missing: \(key)")
}
```

## Result Type

```swift
// Useful for completion handlers and storing outcomes
enum FetchResult {
    case success(User)
    case failure(NetworkError)
}

// Or use built-in Result
func fetchUser(completion: @escaping (Result<User, NetworkError>) -> Void) {
    // ...
    completion(.success(user))
    // or
    completion(.failure(.noConnection))
}

// Converting between Result and throws
let result = Result { try fetchUser(id: "123") }

let user = try result.get()  // Throws if failure
```

## Error Protocol Hierarchy

```swift
// Custom error with context
struct APIError: Error, LocalizedError {
    let endpoint: String
    let statusCode: Int
    let message: String

    var errorDescription: String? { message }
    var failureReason: String? { "HTTP \(statusCode) at \(endpoint)" }
    var recoverySuggestion: String? { "Check your network and try again." }
}

// Domain error wrapping
enum AppError: Error {
    case network(NetworkError)
    case storage(StorageError)
    case validation(String)

    var isRetryable: Bool {
        switch self {
        case .network(.noConnection), .network(.serverError): true
        default: false
        }
    }
}
```

## Rethrows

```swift
// Function that only throws if its closure throws
func retry<T>(times: Int, operation: () throws -> T) rethrows -> T {
    for attempt in 1..<times {
        do { return try operation() }
        catch { continue }
    }
    return try operation()  // Last attempt — propagates error
}

// Non-throwing closure → no try needed
let value = retry(times: 3) { computeValue() }

// Throwing closure → try needed
let user = try retry(times: 3) { try fetchUser() }
```

## SwiftUI Error Handling

```swift
struct ContentView: View {
    @State private var error: Error?
    @State private var showError = false

    var body: some View {
        ContentList()
            .task {
                do {
                    try await loadData()
                } catch {
                    self.error = error
                    showError = true
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("Retry") { Task { try? await loadData() } }
                Button("OK", role: .cancel) { }
            } message: {
                Text(error?.localizedDescription ?? "Unknown error")
            }
    }
}
```

## When to Use What

| Situation | Approach |
|-----------|----------|
| Network call fails | `throws` / `async throws` |
| User input invalid | `throws` with validation error |
| Index out of bounds (your bug) | `fatalError` / `precondition` |
| Optional value missing | Return `nil` (not an error) |
| Need error later | `Result` |
| Multiple error sources | Wrap in domain error enum |

## Anti-Patterns
| ❌ Don't | ✅ Do |
|---------|-------|
| `try!` on network calls | `do-catch` with proper handling |
| Catching all errors silently | Log or surface errors |
| String-based errors | Typed error enums |
| `throws` for programmer bugs | `fatalError` / `assertionFailure` |
| Deeply nested do-catch | Use `try?` or extract functions |

## Related Skills
- `swift-concurrency` — Async error handling
- `swift-networking` — Network error patterns
- `swift-protocols` — Error protocol design
