---
name: swift-testing
description: "Swift testing strategies and frameworks. Keywords: XCTest, Swift Testing, @Test, @Suite, #expect, #require, Preview, UI testing, unit test, mock, stub, parameterized test, 测试, 单元测试, UI测试, 预览"
user-invocable: false
---

# Swift Testing

## Core Principle
**Use Swift Testing (iOS 16+/Xcode 16+) for new tests.** Use XCTest for UI tests and legacy compatibility. SwiftUI Previews are your fastest feedback loop.

## Framework Decision

| Need | Framework |
|------|-----------|
| Unit tests (new) | Swift Testing ✅ |
| Unit tests (legacy) | XCTest |
| UI tests | XCTest (XCUITest) |
| Performance tests | XCTest `.measure { }` |
| Preview-driven development | SwiftUI Previews |

## Swift Testing (Xcode 16+)

### Basic Tests
```swift
import Testing

@Suite("User Model Tests")
struct UserTests {
    @Test("Full name combines first and last")
    func fullName() {
        let user = User(firstName: "Alice", lastName: "Smith")
        #expect(user.fullName == "Alice Smith")
    }

    @Test("Age must be positive")
    func negativeAge() {
        #expect(throws: ValidationError.self) {
            try User(firstName: "Bob", lastName: "Jones", age: -1)
        }
    }

    @Test("Email validation")
    func invalidEmail() throws {
        let user = try User(firstName: "A", lastName: "B", email: "invalid")
        #expect(user.isValid == false)
    }
}
```

### Key Macros
| Macro | Purpose |
|-------|---------|
| `@Test` | Mark a function as a test |
| `@Suite` | Group related tests |
| `#expect(_:)` | Assert condition (soft — continues on failure) |
| `#require(_:)` | Assert condition (hard — stops test on failure) |
| `@Test(.disabled("reason"))` | Skip test |
| `@Test(.bug("URL", "title"))` | Link to known bug |
| `@Test(.tags(.critical))` | Tag for filtering |

### Parameterized Tests
```swift
@Test("Parsing valid numbers", arguments: [
    ("42", 42),
    ("-1", -1),
    ("0", 0),
    ("999", 999)
])
func parseNumber(input: String, expected: Int) throws {
    let result = try NumberParser.parse(input)
    #expect(result == expected)
}

// With enum cases
enum Currency: CaseIterable { case usd, eur, gbp }

@Test("All currencies have symbol", arguments: Currency.allCases)
func currencySymbol(currency: Currency) {
    #expect(!currency.symbol.isEmpty)
}
```

### Async Tests
```swift
@Test("Fetch user from API")
func fetchUser() async throws {
    let client = MockAPIClient()
    let user = try await client.fetchUser(id: "123")
    #expect(user.name == "Alice")
}
```

### Setup and Teardown
```swift
@Suite("Database Tests")
struct DatabaseTests {
    let db: TestDatabase

    init() async throws {
        db = try await TestDatabase.create()
        try await db.seed()
    }

    // deinit equivalent — Swift Testing cleans up after each test

    @Test func insertItem() async throws {
        try await db.insert(Item(name: "Test"))
        let items = try await db.fetchAll()
        #expect(items.count == 1)
    }
}
```

## XCTest (Legacy / UI Tests)

### Unit Test
```swift
import XCTest
@testable import MyApp

final class UserTests: XCTestCase {
    var sut: UserService!  // System Under Test

    override func setUp() {
        sut = UserService(api: MockAPI())
    }

    override func tearDown() {
        sut = nil
    }

    func testFetchUser() async throws {
        let user = try await sut.fetchUser(id: "123")
        XCTAssertEqual(user.name, "Alice")
        XCTAssertNotNil(user.email)
    }
}
```

### UI Test
```swift
final class LoginUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launch()
    }

    func testLoginFlow() {
        let emailField = app.textFields["email"]
        emailField.tap()
        emailField.typeText("alice@example.com")

        let passwordField = app.secureTextFields["password"]
        passwordField.tap()
        passwordField.typeText("password123")

        app.buttons["Login"].tap()

        XCTAssertTrue(app.staticTexts["Welcome, Alice"].waitForExistence(timeout: 5))
    }
}
```

## Mocking & Dependency Injection

```swift
// Protocol-based mocking
protocol UserRepository {
    func fetch(id: String) async throws -> User
}

struct RealUserRepository: UserRepository {
    func fetch(id: String) async throws -> User {
        try await api.fetchUser(id: id)
    }
}

struct MockUserRepository: UserRepository {
    var stubbedUsers: [String: User] = [:]
    var fetchCallCount = 0

    mutating func fetch(id: String) async throws -> User {
        fetchCallCount += 1
        guard let user = stubbedUsers[id] else {
            throw TestError.notFound
        }
        return user
    }
}

// Usage in test
@Test func viewModelLoadsUser() async {
    var mock = MockUserRepository()
    mock.stubbedUsers["123"] = User(name: "Alice")

    let vm = UserViewModel(repository: mock)
    await vm.loadUser(id: "123")

    #expect(vm.user?.name == "Alice")
}
```

## SwiftUI Previews as Testing

```swift
// Previews = visual unit tests
#Preview("Item List — Empty") {
    ItemListView(items: [])
}

#Preview("Item List — Loaded") {
    ItemListView(items: Item.samples)
}

#Preview("Item List — Error") {
    ItemListView(items: [], error: .networkUnavailable)
}

// Preview with state
#Preview("Toggle Example") {
    @Previewable @State var isOn = false
    Toggle("Dark Mode", isOn: $isOn)
}

// Preview with environment
#Preview("Settings") {
    SettingsView()
        .environment(AuthManager.preview)
        .modelContainer(previewContainer)
}
```

## Test Organization

```
Tests/
├── UnitTests/
│   ├── Models/
│   │   └── UserTests.swift
│   ├── ViewModels/
│   │   └── UserViewModelTests.swift
│   └── Services/
│       └── APIClientTests.swift
├── IntegrationTests/
│   └── DatabaseIntegrationTests.swift
├── UITests/
│   └── LoginUITests.swift
└── Helpers/
    ├── Mocks.swift
    └── TestFixtures.swift
```

## Swift Testing vs XCTest

| Feature | Swift Testing | XCTest |
|---------|--------------|--------|
| Syntax | `@Test`, `#expect` | `func test...`, `XCTAssert...` |
| Parameterized | Built-in `arguments:` | Manual loops |
| Parallelism | Default parallel | Serial by default |
| Tags/filtering | `@Test(.tags(...))` | Test plans |
| UI testing | Not supported | XCUITest |
| Performance | Not yet | `.measure { }` |
| Min Xcode | 16+ | Any |

## Anti-Patterns
| Don't | Do |
|---------|-------|
| Test implementation details | Test behavior / public API |
| Mocking everything | Only mock external dependencies |
| Ignoring Previews | Use as visual regression tests |
| No tests for edge cases | Test nil, empty, error states |
| Giant test methods | One assertion concept per test |

## Related Skills
- `swift-error-handling` — Testing error paths
- `swift-concurrency` — Testing async code
- `swift-data-flow` — Testing ViewModels
