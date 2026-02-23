---
name: swift-protocols
description: "Protocol-oriented programming and generics in Swift. Keywords: protocol, associatedtype, some, any, opaque type, existential, generic, where clause, type erasure, primary associated type, 协议, 泛型, 协议导向编程, 类型擦除"
user-invocable: false
---

# Swift Protocols & Generics

## Core Principle
**Protocol-oriented over class inheritance.** Prefer `some` (opaque) over `any` (existential) for performance. Use generics for type-safe abstractions.

## Decision Flow

```
Need shared interface?
  → protocol ✅

Need concrete type hidden behind protocol?
  → some Protocol (opaque type) ✅

Need dynamic dispatch / heterogeneous collection?
  → any Protocol (existential) ✅

Need type-safe container/algorithm?
  → Generics with constraints ✅
```

## Protocol Basics

```swift
protocol Drawable {
    func draw(in rect: CGRect)
    var boundingBox: CGRect { get }
}

// Default implementation via extension
extension Drawable {
    var boundingBox: CGRect { .zero }
}

struct Circle: Drawable {
    let center: CGPoint
    let radius: CGFloat

    func draw(in rect: CGRect) { /* ... */ }
}
```

## some vs any (Swift 5.7+)

### `some` — Opaque Type (Preferred)
```swift
// Compiler knows the concrete type — static dispatch, better performance
func makeShape() -> some Drawable {
    Circle(center: .zero, radius: 10)  // Always returns Circle
}

// In SwiftUI — body is `some View`
var body: some View {
    Text("Hello")
}
```

### `any` — Existential Type (When Needed)
```swift
// Can hold any conforming type — dynamic dispatch, boxing overhead
var shapes: [any Drawable] = [
    Circle(center: .zero, radius: 10),
    Square(origin: .zero, size: 20)
]

func processShape(_ shape: any Drawable) {
    shape.draw(in: shape.boundingBox)
}
```

### When to Use Which

| Scenario | Use |
|----------|-----|
| Return type (always same concrete type) | `some Protocol` |
| SwiftUI view body | `some View` |
| Heterogeneous collection | `[any Protocol]` |
| Parameter accepting multiple types | Generic `<T: Protocol>` or `some Protocol` |
| Property with varying concrete type | `any Protocol` |
| Performance-critical code | `some` or generics (static dispatch) |

## Associated Types

```swift
protocol Repository {
    associatedtype Model: Identifiable

    func fetch(id: Model.ID) async throws -> Model
    func save(_ model: Model) async throws
    func delete(id: Model.ID) async throws
}

struct UserRepository: Repository {
    typealias Model = User  // Or inferred from method signatures

    func fetch(id: User.ID) async throws -> User { /* ... */ }
    func save(_ user: User) async throws { /* ... */ }
    func delete(id: User.ID) async throws { /* ... */ }
}
```

### Primary Associated Types (Swift 5.7+)
```swift
// Declare primary associated type
protocol Collection<Element>: Sequence {
    associatedtype Element
    // ...
}

// Use in constrained existential
func process(items: some Collection<String>) {
    for item in items { print(item) }
}

// Or with any
var anyStrings: any Collection<String> = [1, 2, 3].map(String.init)
```

## Generics

```swift
// Generic function
func firstMatch<T: Equatable>(in array: [T], matching value: T) -> Int? {
    array.firstIndex(of: value)
}

// Generic type
struct Stack<Element> {
    private var items: [Element] = []
    mutating func push(_ item: Element) { items.append(item) }
    mutating func pop() -> Element? { items.popLast() }
}

// Where clause for complex constraints
func merge<C1: Collection, C2: Collection>(
    _ first: C1, _ second: C2
) -> [C1.Element] where C1.Element == C2.Element, C1.Element: Comparable {
    (Array(first) + Array(second)).sorted()
}
```

## Protocol Composition

```swift
// Combine protocols
func configure(item: some Drawable & Codable) {
    // item conforms to both Drawable and Codable
}

// Typealias for readability
typealias PersistableDrawable = Drawable & Codable & Identifiable
```

## Protocol Extensions & Conditional Conformance

```swift
// Default implementations
extension Collection where Element: Numeric {
    var total: Element {
        reduce(0, +)
    }
}

// Conditional conformance
extension Array: Drawable where Element: Drawable {
    func draw(in rect: CGRect) {
        for element in self { element.draw(in: rect) }
    }
}

// Optional conforms to Equatable when Wrapped does
// (Already in stdlib — this is the pattern)
```

## Common Protocol Patterns

### Protocol Witness (Lightweight Alternative)
```swift
// Instead of protocol + conformance, use closures
struct Fetcher<T> {
    let fetch: () async throws -> T
}

let userFetcher = Fetcher { try await api.getUser() }
let result = try await userFetcher.fetch()
```

### Protocol with Self Requirement
```swift
protocol Copyable {
    func copy() -> Self
}

// ⚠️ Cannot use as existential: any Copyable
// Must use as generic constraint: some Copyable or <T: Copyable>
```

## SwiftUI Protocol Usage
```swift
// View protocol — always returns some View
struct MyView: View {
    var body: some View { Text("Hello") }
}

// ViewModifier
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.white)
            .cornerRadius(12)
            .shadow(radius: 4)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}
```

## Anti-Patterns
| ❌ Don't | ✅ Do |
|---------|-------|
| `any Protocol` when `some` works | Use `some Protocol` for static dispatch |
| Class inheritance hierarchies | Protocol + composition |
| Protocol for single conformance | Just use the type directly |
| `AnyPublisher` type erasure (legacy) | `some Publisher<Output, Failure>` (modern) |
| Protocol with tons of default impls | Consider struct + closures |

## Related Skills
- `swift-swiftui-first` — View protocol and modifiers
- `swift-error-handling` — Error protocol patterns
- `swift-performance` — Static vs dynamic dispatch cost
