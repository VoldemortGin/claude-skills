---
name: swift-networking
description: "Swift networking layer patterns with URLSession and Codable. Keywords: URLSession, async networking, Codable, JSON, REST API, WebSocket, HTTP, URLRequest, JSONDecoder, multipart, download, upload, 网络请求, API调用, JSON解析"
user-invocable: false
---

# Swift Networking

## Core Principle
**Use URLSession with async/await.** No need for Alamofire in most cases. Codable is your JSON layer.

## Basic Async Networking

```swift
// Simple GET
func fetchUser(id: String) async throws -> User {
    let url = URL(string: "https://api.example.com/users/\(id)")!
    let (data, response) = try await URLSession.shared.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw NetworkError.invalidResponse
    }

    return try JSONDecoder().decode(User.self, from: data)
}

// POST with body
func createUser(_ user: CreateUserRequest) async throws -> User {
    var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(user)

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 201 else {
        throw NetworkError.invalidResponse
    }
    return try JSONDecoder().decode(User.self, from: data)
}
```

## API Client Pattern

```swift
actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        headers: [String: String] = [:]
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(
                statusCode: httpResponse.statusCode,
                data: data
            )
        }

        return try decoder.decode(T.self, from: data)
    }

    // Convenience methods
    func get<T: Decodable>(_ endpoint: String) async throws -> T {
        try await request(endpoint)
    }

    func post<T: Decodable>(_ endpoint: String, body: some Encodable) async throws -> T {
        try await request(endpoint, method: "POST", body: body)
    }
}

// Usage
let api = APIClient(baseURL: URL(string: "https://api.example.com")!)
let users: [User] = try await api.get("/users")
let newUser: User = try await api.post("/users", body: CreateUserRequest(name: "Alice"))
```

## Codable Best Practices

```swift
struct User: Codable, Identifiable {
    let id: Int
    let name: String
    let email: String
    let createdAt: Date

    // Custom keys
    enum CodingKeys: String, CodingKey {
        case id, name, email
        case createdAt = "created_at"  // Or use .convertFromSnakeCase
    }
}

// Nested JSON
struct APIResponse<T: Decodable>: Decodable {
    let data: T
    let meta: Meta?

    struct Meta: Decodable {
        let page: Int
        let totalPages: Int
    }
}

// Decoding with custom strategy
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
decoder.dateDecodingStrategy = .custom { decoder in
    let container = try decoder.singleValueContainer()
    let string = try container.decode(String.self)
    // Try multiple date formats
    for formatter in [iso8601Full, iso8601Date] {
        if let date = formatter.date(from: string) { return date }
    }
    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date")
}
```

## Download & Upload

```swift
// Download with progress
func downloadFile(from url: URL) async throws -> URL {
    let (localURL, response) = try await URLSession.shared.download(from: url)
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw NetworkError.downloadFailed
    }
    // Move to permanent location
    let destination = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
    try FileManager.default.moveItem(at: localURL, to: destination)
    return destination
}

// Upload
func uploadImage(_ imageData: Data) async throws -> UploadResponse {
    var request = URLRequest(url: URL(string: "https://api.example.com/upload")!)
    request.httpMethod = "POST"

    let boundary = UUID().uuidString
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var body = Data()
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
    body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
    body.append(imageData)
    body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

    let (data, _) = try await URLSession.shared.upload(for: request, from: body)
    return try JSONDecoder().decode(UploadResponse.self, from: data)
}
```

## WebSocket

```swift
func connectWebSocket() async throws {
    let url = URL(string: "wss://api.example.com/ws")!
    let task = URLSession.shared.webSocketTask(with: url)
    task.resume()

    // Send
    try await task.send(.string("{\"type\": \"subscribe\", \"channel\": \"updates\"}"))

    // Receive loop
    while true {
        let message = try await task.receive()
        switch message {
        case .string(let text):
            print("Received: \(text)")
        case .data(let data):
            print("Received data: \(data.count) bytes")
        @unknown default:
            break
        }
    }
}
```

## SwiftUI Integration

```swift
@Observable
class UserListViewModel {
    var users: [User] = []
    var isLoading = false
    var error: Error?

    private let api: APIClient

    init(api: APIClient) { self.api = api }

    func loadUsers() async {
        isLoading = true
        defer { isLoading = false }
        do {
            users = try await api.get("/users")
        } catch {
            self.error = error
        }
    }
}

struct UserListView: View {
    @State private var viewModel: UserListViewModel

    init(api: APIClient) {
        _viewModel = State(initialValue: UserListViewModel(api: api))
    }

    var body: some View {
        List(viewModel.users) { user in
            Text(user.name)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .task {
            await viewModel.loadUsers()
        }
        .refreshable {
            await viewModel.loadUsers()
        }
    }
}
```

## Anti-Patterns
| Don't | Do |
|---------|-------|
| Alamofire for simple REST | URLSession + async/await |
| Force unwrap URLs | Guard + throw |
| Decode in ViewController | Decode in network layer |
| Ignore HTTP status codes | Check response status |
| Hardcode base URLs | Use configuration / environment |

## Related Skills
- `swift-concurrency` -- Async patterns for networking
- `swift-error-handling` -- Network error handling
- `swift-persistence` -- Caching strategies
