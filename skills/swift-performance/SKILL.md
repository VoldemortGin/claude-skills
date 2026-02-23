---
name: swift-performance
description: "Swift and SwiftUI performance optimization. Keywords: Instruments, performance, lazy, @MainActor, rendering, profiling, Time Profiler, Allocations, SwiftUI body evaluation, Equatable, 性能, 卡顿, 优化, 渲染性能, 内存分析"
user-invocable: false
---

# Swift Performance Optimization

## Core Principle
**Measure first, optimize second.** Use Instruments to find actual bottlenecks. Premature optimization wastes time.

## Performance Diagnosis Flow

```
App feels slow?
  → Profile with Instruments first

UI stuttering/dropping frames?
  → Time Profiler → Find main thread work
  → SwiftUI Instruments → Check body evaluations

High memory?
  → Allocations instrument → Find retained objects
  → Leaks instrument → Find retain cycles

Slow launch?
  → App Launch instrument → Reduce pre-main and post-main work
```

## Instruments Quick Guide

| Instrument | When to Use |
|------------|-------------|
| **Time Profiler** | CPU hotspots, slow functions |
| **Allocations** | Memory usage, object counts |
| **Leaks** | Retain cycles, leaked objects |
| **SwiftUI** | View body evaluations, update frequency |
| **Core Animation** | Rendering, offscreen passes |
| **Network** | Request timing, payload sizes |
| **App Launch** | Startup time breakdown |
| **Energy** | Battery drain causes |

## SwiftUI Performance

### Minimize Body Evaluations
```swift
// ❌ Bad: Parent change re-evaluates all children
struct ParentView: View {
    @State private var count = 0
    @State private var name = "Alice"

    var body: some View {
        VStack {
            Text("Count: \(count)")
            ExpensiveChildView(name: name)  // Re-evaluated when count changes!
        }
    }
}

// ✅ Good: Extract into subview with only needed dependencies
struct CounterView: View {
    @State private var count = 0

    var body: some View {
        VStack {
            Text("Count: \(count)")
            Button("+") { count += 1 }
        }
    }
}
```

### Equatable for View Skipping
```swift
// Mark views as Equatable to skip unnecessary updates
struct ItemRow: View, Equatable {
    let item: Item

    static func == (lhs: ItemRow, rhs: ItemRow) -> Bool {
        lhs.item.id == rhs.item.id && lhs.item.name == rhs.item.name
    }

    var body: some View {
        HStack {
            Text(item.name)
            Spacer()
            Text(item.date, style: .relative)
        }
    }
}
```

### Lazy Loading
```swift
// ✅ Use Lazy containers for large lists
LazyVStack {  // Only renders visible items
    ForEach(items) { item in
        ItemRow(item: item)
    }
}

// ❌ VStack renders ALL items immediately
VStack {
    ForEach(items) { item in  // 10000 items? All created upfront
        ItemRow(item: item)
    }
}

// LazyVGrid / LazyHGrid for grids
LazyVGrid(columns: columns) {
    ForEach(items) { item in
        ItemCard(item: item)
    }
}
```

### Avoid Expensive Operations in body
```swift
// ❌ Computing in body
var body: some View {
    let sorted = items.sorted { $0.date > $1.date }  // Every evaluation!
    List(sorted) { ... }
}

// ✅ Compute in view model or use @State
@State private var sortedItems: [Item] = []

var body: some View {
    List(sortedItems) { ... }
        .onChange(of: items) { _, new in
            sortedItems = new.sorted { $0.date > $1.date }
        }
}
```

## General Swift Performance

### Value Types vs Reference Types
```swift
// Prefer structs for data — stack allocated, no ARC overhead
struct Point { var x: Double; var y: Double }  // ✅ Fast

// Classes — heap allocated, ARC counting
class PointClass { var x: Double = 0; var y: Double = 0 }  // Slower for simple data
```

### Collection Performance
```swift
// Pre-allocate when size is known
var results = [Result]()
results.reserveCapacity(items.count)  // Avoid reallocations

// Use lazy for chained operations
let names = largeArray
    .lazy
    .filter { $0.isActive }
    .map { $0.name }
    .prefix(10)  // Only processes what's needed

// ContiguousArray for non-class elements (rare optimization)
var points = ContiguousArray<Point>()
```

### String Performance
```swift
// String interpolation is fine for most cases
let msg = "Hello \(name)"

// For tight loops, use String.append or Array<UInt8>
var builder = ""
builder.reserveCapacity(estimatedLength)
for item in items {
    builder.append(item.name)
    builder.append(", ")
}
```

### @MainActor and Threading
```swift
// Heavy work OFF main thread
@MainActor
class ViewModel {
    func processData() async {
        // Move heavy work off MainActor
        let result = await Task.detached(priority: .userInitiated) {
            // Heavy computation here — NOT on main thread
            return self.crunchNumbers(data)
        }.value

        // Back on MainActor for UI update
        self.items = result
    }
}
```

## Image Performance

```swift
// ✅ Downsampling large images
func downsample(imageAt url: URL, to pointSize: CGSize, scale: CGFloat) -> UIImage? {
    let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale
    let options = [
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels,
        kCGImageSourceCreateThumbnailWithTransform: true
    ] as CFDictionary

    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
        return nil
    }
    return UIImage(cgImage: cgImage)
}

// ✅ AsyncImage with proper caching
AsyncImage(url: imageURL) { image in
    image.resizable().scaledToFit()
} placeholder: {
    ProgressView()
}
```

## Common Performance Wins

| Issue | Fix |
|-------|-----|
| List/ScrollView stuttering | Use `LazyVStack` / `LazyVGrid` |
| Too many body evaluations | Extract subviews, use `Equatable` |
| Large images | Downsample to display size |
| Main thread blocking | Move work to `Task.detached` |
| Frequent object allocation | Use value types (struct) |
| Repeated sorting/filtering | Cache results, compute on change |
| Animation jank | Animate transforms, not layout |
| Slow JSON parsing | Profile decoder, use `@Transient` for computed |

## Anti-Patterns
| ❌ Don't | ✅ Do |
|---------|-------|
| Optimize without profiling | Use Instruments first |
| `VStack` with 1000+ items | `LazyVStack` |
| Full-res images in thumbnails | Downsample |
| Heavy computation in `.body` | Use view model / `.task` |
| Premature `Equatable` everywhere | Profile first, optimize hot views |

## Related Skills
- `swift-memory` — Memory profiling and leaks
- `swift-concurrency` — Offloading work from main thread
- `swift-layout` — Layout performance
