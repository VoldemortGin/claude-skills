---
name: swift-persistence
description: "Data persistence strategies in Swift. Keywords: SwiftData, CoreData, @Model, @Query, ModelContainer, ModelContext, UserDefaults, Keychain, FileManager, CloudKit, 持久化, 数据库, 本地存储, 数据模型"
user-invocable: false
---

# Swift Data Persistence

## Core Principle
**Use SwiftData for structured data (iOS 17+).** Use UserDefaults only for small preferences. Use Keychain for secrets.

## Decision Matrix

| Data Type | Solution | Min Version |
|-----------|----------|-------------|
| User preferences (small) | `@AppStorage` / `UserDefaults` | iOS 14+ |
| Sensitive data (tokens, passwords) | Keychain | iOS 2+ |
| Structured domain data | SwiftData | iOS 17+ |
| Structured data (legacy) | Core Data | iOS 3+ |
| Files (images, documents) | `FileManager` | iOS 2+ |
| Cloud sync | CloudKit + SwiftData | iOS 17+ |
| Simple key-value sync | `NSUbiquitousKeyValueStore` | iOS 5+ |

## SwiftData (iOS 17+)

### Model Definition
```swift
import SwiftData

@Model
class Item {
    var title: String
    var timestamp: Date
    var isComplete: Bool

    @Relationship(deleteRule: .cascade)
    var tags: [Tag]

    @Attribute(.externalStorage)  // Store large data externally
    var imageData: Data?

    @Transient  // Not persisted
    var isSelected: Bool = false

    init(title: String, timestamp: Date = .now) {
        self.title = title
        self.timestamp = timestamp
        self.isComplete = false
        self.tags = []
    }
}

@Model
class Tag {
    var name: String
    var items: [Item]  // Inverse relationship auto-managed

    init(name: String) { self.name = name }
}
```

### Container Setup
```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Item.self, Tag.self])
        // Or with configuration:
        // .modelContainer(for: Item.self, inMemory: false, isAutosaveEnabled: true)
    }
}
```

### CRUD with @Query and @Environment
```swift
struct ItemListView: View {
    @Query(sort: \Item.timestamp, order: .reverse)
    private var items: [Item]

    @Query(filter: #Predicate<Item> { $0.isComplete == false })
    private var pendingItems: [Item]

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List(items) { item in
            ItemRow(item: item)
                .swipeActions {
                    Button(role: .destructive) {
                        modelContext.delete(item)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
        .toolbar {
            Button("Add") {
                let item = Item(title: "New Item")
                modelContext.insert(item)
                // Auto-saves (if autosave enabled)
            }
        }
    }
}
```

### Querying
```swift
// Dynamic query
@Query private var items: [Item]

init(showCompleted: Bool) {
    let predicate = #Predicate<Item> {
        showCompleted || !$0.isComplete
    }
    _items = Query(filter: predicate, sort: \.timestamp)
}

// FetchDescriptor for programmatic access
func search(keyword: String) throws -> [Item] {
    let descriptor = FetchDescriptor<Item>(
        predicate: #Predicate { $0.title.contains(keyword) },
        sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
    )
    return try modelContext.fetch(descriptor)
}
```

## UserDefaults / @AppStorage

```swift
// SwiftUI — @AppStorage
struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("fontSize") private var fontSize = 14.0
    @AppStorage("username") private var username = ""

    var body: some View {
        Toggle("Dark Mode", isOn: $isDarkMode)
        Slider(value: $fontSize, in: 10...24)
    }
}

// Direct UserDefaults (non-SwiftUI)
UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
```

### UserDefaults Limits
- Small data only (< 1MB total recommended)
- Not encrypted — never store secrets
- Synchronous — don't store large blobs
- Types: Bool, Int, Double, String, Data, Date, Array, Dictionary

## Keychain

```swift
// Simple keychain wrapper
func saveToKeychain(key: String, value: String) throws {
    let data = value.data(using: .utf8)!
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data
    ]
    SecItemDelete(query as CFDictionary)  // Remove old
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw KeychainError.saveFailed(status)
    }
}

func readFromKeychain(key: String) throws -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
}
```

> **Tip:** Use a library like [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) for cleaner API.

## FileManager

```swift
// Save to documents directory
func saveImage(_ image: UIImage, name: String) throws -> URL {
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let fileURL = documentsURL.appendingPathComponent(name)
    guard let data = image.jpegData(compressionQuality: 0.8) else {
        throw StorageError.encodingFailed
    }
    try data.write(to: fileURL)
    return fileURL
}
```

## SwiftData vs Core Data

| Feature | SwiftData | Core Data |
|---------|-----------|-----------|
| Min version | iOS 17 | iOS 3 |
| Model definition | `@Model` class | `.xcdatamodeld` + NSManagedObject |
| Query | `@Query` + `#Predicate` | `NSFetchRequest` + `NSPredicate` |
| Context | `ModelContext` | `NSManagedObjectContext` |
| SwiftUI integration | Native | Via `@FetchRequest` |
| Migration | Automatic (simple) | Mapping models |
| CloudKit | Built-in | NSPersistentCloudKitContainer |

## Anti-Patterns
| ❌ Don't | ✅ Do |
|---------|-------|
| Tokens in UserDefaults | Use Keychain |
| Large blobs in UserDefaults | Use FileManager |
| Core Data for new iOS 17+ projects | Use SwiftData |
| Manual JSON file for structured data | Use SwiftData |
| Forget `@Transient` for computed/temp props | Mark non-persisted properties |

## Related Skills
- `swift-data-flow` — @Query and @Environment for SwiftData
- `swift-networking` — Caching network responses
- `swift-multiplatform` — Platform-specific storage paths
