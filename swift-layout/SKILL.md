---
name: swift-layout
description: "SwiftUI and UIKit layout systems. Keywords: HStack, VStack, ZStack, LazyVGrid, LazyHGrid, GeometryReader, Layout protocol, Auto Layout, constraints, frame, padding, Spacer, alignment, 布局, 排版, 自适应布局"
user-invocable: false
---

# Swift Layout System

## Core Principle
**Use SwiftUI stacks and modifiers first.** Only use `GeometryReader` when you truly need parent dimensions. Never use Auto Layout in SwiftUI.

## Layout Decision Flow

```
Simple row/column?
  → HStack / VStack ✅

Overlapping views?
  → ZStack ✅

Scrollable grid?
  → LazyVGrid / LazyHGrid ✅

Need parent size?
  → GeometryReader (sparingly) ✅

Custom layout algorithm?
  → Layout protocol (iOS 16+) ✅

UIKit only? → Auto Layout + NSLayoutConstraint
```

## SwiftUI Stack Layouts

```swift
// Basic stacks
VStack(alignment: .leading, spacing: 12) {
    Text("Title").font(.headline)
    Text("Subtitle").font(.subheadline)
}

HStack(spacing: 8) {
    Image(systemName: "star")
    Text("Favorite")
    Spacer()  // Push remaining content to trailing
    Text("99")
}

ZStack(alignment: .bottomTrailing) {
    Image("photo")
    Badge(count: 3)  // Overlaid at bottom-trailing
}
```

## Sizing & Spacing

```swift
Text("Hello")
    .frame(width: 200, height: 44)          // Fixed size
    .frame(maxWidth: .infinity)              // Expand to fill
    .frame(minHeight: 44)                    // Minimum height
    .padding()                               // Default padding (16pt)
    .padding(.horizontal, 20)               // Specific edge
    .padding(.vertical, 8)
```

### Frame Behavior
| Modifier | Effect |
|----------|--------|
| `.frame(width: 100)` | Fixed width |
| `.frame(maxWidth: .infinity)` | Fill available width |
| `.frame(minWidth: 50, maxWidth: 200)` | Flexible range |
| `.frame(maxWidth: .infinity, alignment: .leading)` | Fill + align left |

## Grids

```swift
// Adaptive grid (auto-fills columns)
let columns = [GridItem(.adaptive(minimum: 100, maximum: 200))]

LazyVGrid(columns: columns, spacing: 16) {
    ForEach(items) { item in
        ItemCard(item: item)
    }
}

// Fixed column count
let columns = [
    GridItem(.flexible()),
    GridItem(.flexible()),
    GridItem(.flexible())
]  // 3 equal columns

// Mixed
let columns = [
    GridItem(.fixed(80)),       // Fixed 80pt
    GridItem(.flexible()),      // Takes remaining space
]
```

## GeometryReader (Use Sparingly)

```swift
// ✅ Good: reading size for proportional layout
GeometryReader { geometry in
    HStack(spacing: 0) {
        SideBar()
            .frame(width: geometry.size.width * 0.3)
        MainContent()
            .frame(width: geometry.size.width * 0.7)
    }
}

// ❌ Bad: using GeometryReader when .frame(maxWidth:) suffices
```

### Alternatives to GeometryReader
| Need | Use Instead |
|------|-------------|
| Fill width | `.frame(maxWidth: .infinity)` |
| Aspect ratio | `.aspectRatio(16/9, contentMode: .fit)` |
| Relative sizing | `Layout` protocol or `HStack` with flexible items |
| Safe area | `.safeAreaInset` |

## Layout Protocol (iOS 16+)

```swift
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(
                x: bounds.minX + position.x,
                y: bounds.minY + position.y
            ), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        // Flow layout algorithm
    }
}

// Usage
FlowLayout(spacing: 8) {
    ForEach(tags) { tag in
        TagView(tag: tag)
    }
}
```

## ViewThatFits (iOS 16+)

```swift
// Automatically picks the first view that fits
ViewThatFits {
    // Try horizontal first
    HStack { labels }
    // Fall back to vertical
    VStack { labels }
}
```

## ScrollView

```swift
ScrollView {
    LazyVStack(spacing: 12) {  // Lazy = only renders visible items
        ForEach(items) { item in
            ItemRow(item: item)
        }
    }
    .padding()
}

// Scroll position (iOS 17+)
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            ItemRow(item: item)
                .id(item.id)
        }
    }
    .scrollTargetLayout()
}
.scrollPosition(id: $scrolledID)
```

## SwiftUI vs UIKit Layout

| SwiftUI | UIKit |
|---------|-------|
| `VStack` | `UIStackView(.vertical)` |
| `HStack` | `UIStackView(.horizontal)` |
| `.frame()` | `NSLayoutConstraint` (width/height) |
| `.padding()` | `layoutMargins` / constraint constants |
| `LazyVGrid` | `UICollectionView` + `UICollectionViewFlowLayout` |
| `GeometryReader` | `viewDidLayoutSubviews` |
| `Layout` protocol | `UICollectionViewCompositionalLayout` |

**Need UIKit for:** Complex compositional collection layouts, self-sizing cells with complex rules, drag-to-reorder with custom animations.

## Anti-Patterns
| ❌ Don't | ✅ Do |
|---------|-------|
| `GeometryReader` everywhere | Use `.frame(maxWidth:)` |
| Hardcoded dimensions | Use relative sizing, Dynamic Type |
| Nested `ScrollView` same axis | Use sections in one `ScrollView` |
| `.frame` before `.padding` | `.padding` then `.frame` (modifiers are outside-in) |

## Related Skills
- `swift-swiftui-first` — Framework decision
- `swift-animation` — Animated layout changes
- `swift-multiplatform` — Platform-specific layouts
