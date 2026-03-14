---
name: swift-animation
description: "SwiftUI animation system and techniques. Keywords: withAnimation, .animation, matchedGeometryEffect, transition, KeyframeAnimator, PhaseAnimator, spring, easeInOut, implicit animation, explicit animation, 动画, 过渡动画, 转场"
user-invocable: false
---

# Swift Animation System

## Core Principle
**Use SwiftUI implicit animations by default. Use explicit `withAnimation` when you need control. Drop to UIKit only for interactive/interruptible transitions.**

## Animation Decision Flow

```
Simple state-driven animation?
  -> .animation() modifier (implicit)

Triggered by action (button tap)?
  -> withAnimation { } (explicit)

Shared element transition?
  -> matchedGeometryEffect

Multi-step sequence?
  -> PhaseAnimator (iOS 17+)

Complex keyframe?
  -> KeyframeAnimator (iOS 17+)

View appearing/disappearing?
  -> .transition()

Interactive/interruptible transition?
  -> UIKit (UIViewPropertyAnimator)
```

## Implicit Animation

```swift
struct ToggleView: View {
    @State private var isExpanded = false

    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.blue)
                .frame(width: isExpanded ? 300 : 100, height: isExpanded ? 200 : 100)
                .animation(.spring(duration: 0.5, bounce: 0.3), value: isExpanded)

            Button("Toggle") { isExpanded.toggle() }
        }
    }
}
```

## Explicit Animation

```swift
Button("Toggle") {
    withAnimation(.easeInOut(duration: 0.3)) {
        isExpanded.toggle()
    }
}

// With completion (iOS 17+)
withAnimation(.spring(duration: 0.5)) {
    isExpanded.toggle()
} completion: {
    // Called when animation finishes
    showNextStep = true
}
```

## Animation Types

| Animation | Use Case |
|-----------|----------|
| `.spring()` | Natural, bouncy motion (default recommended) |
| `.spring(duration:bounce:)` | Controlled spring |
| `.easeInOut` | Smooth acceleration/deceleration |
| `.easeIn` | Slow start |
| `.easeOut` | Slow end |
| `.linear` | Constant speed |
| `.interactiveSpring` | Gesture-driven animations |
| `.snappy` | Quick, responsive (iOS 17+) |
| `.bouncy` | More bounce (iOS 17+) |
| `.smooth` | Smooth curve (iOS 17+) |

```swift
// Customization
.animation(.spring(duration: 0.6, bounce: 0.2).delay(0.1), value: isVisible)
.animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: isPulsing)
```

## Transitions

```swift
struct ContentView: View {
    @State private var showDetail = false

    var body: some View {
        VStack {
            if showDetail {
                DetailView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring, value: showDetail)
    }
}

// Built-in transitions
.transition(.opacity)           // Fade
.transition(.slide)             // Slide from leading
.transition(.move(edge: .bottom)) // Slide from bottom
.transition(.scale)             // Scale from center
.transition(.push(from: .bottom)) // Push (iOS 16+)
```

## matchedGeometryEffect -- Shared Element Transitions

```swift
struct ListView: View {
    @Namespace private var animation
    @State private var selectedItem: Item?

    var body: some View {
        if let selected = selectedItem {
            // Detail view
            DetailView(item: selected)
                .matchedGeometryEffect(id: selected.id, in: animation)
                .onTapGesture { withAnimation(.spring) { selectedItem = nil } }
        } else {
            // Grid view
            LazyVGrid(columns: columns) {
                ForEach(items) { item in
                    ItemCard(item: item)
                        .matchedGeometryEffect(id: item.id, in: animation)
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.5)) {
                                selectedItem = item
                            }
                        }
                }
            }
        }
    }
}
```

## PhaseAnimator (iOS 17+) -- Multi-Step

```swift
struct PulsingView: View {
    var body: some View {
        PhaseAnimator([false, true]) { phase in
            Circle()
                .fill(phase ? .red : .blue)
                .scaleEffect(phase ? 1.2 : 1.0)
                .opacity(phase ? 0.8 : 1.0)
        } animation: { phase in
            .easeInOut(duration: 0.8)
        }
    }
}

// Custom phases
enum AnimationPhase: CaseIterable {
    case start, middle, end
}

PhaseAnimator(AnimationPhase.allCases) { phase in
    Image(systemName: "star.fill")
        .scaleEffect(phase == .middle ? 1.5 : 1.0)
        .rotationEffect(.degrees(phase == .end ? 360 : 0))
}
```

## KeyframeAnimator (iOS 17+) -- Precise Control

```swift
struct BounceView: View {
    var body: some View {
        KeyframeAnimator(initialValue: AnimationValues()) { values in
            Image(systemName: "heart.fill")
                .scaleEffect(y: values.verticalStretch)
                .offset(y: values.translation)
        } keyframes: { _ in
            KeyframeTrack(\.translation) {
                SpringKeyframe(-100, duration: 0.3, spring: .bouncy)
                SpringKeyframe(0, duration: 0.5, spring: .bouncy)
            }
            KeyframeTrack(\.verticalStretch) {
                LinearKeyframe(1.2, duration: 0.1)
                SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
            }
        }
    }
}

struct AnimationValues {
    var translation: CGFloat = 0
    var verticalStretch: CGFloat = 1.0
}
```

## SwiftUI vs UIKit Animation

| SwiftUI | UIKit |
|---------|-------|
| `.animation()` | `UIView.animate()` |
| `withAnimation` | `UIView.animate()` explicit |
| `.transition()` | `UIView.transition()` |
| `matchedGeometryEffect` | Custom `UIViewControllerTransitioningDelegate` |
| `KeyframeAnimator` | `CAKeyframeAnimation` |
| N/A | `UIViewPropertyAnimator` (interruptible) |

**Need UIKit for:** Interactive transitions (pan-to-dismiss), `UIViewPropertyAnimator` with scrubbing, complex layer-based animations (`CAAnimation`).

## Anti-Patterns
| Don't | Do |
|---------|-------|
| `.animation(.default)` (deprecated) | `.animation(.spring, value: property)` |
| Animate layout-heavy views | Animate transforms (offset, scale, opacity) |
| withAnimation on large view tree | Scope animation to changing property |
| GeometryReader for animation | matchedGeometryEffect |
| Forget `value:` parameter | Always specify what triggers animation |

## Related Skills
- `swift-layout` -- Layout changes triggering animations
- `swift-swiftui-first` -- When to drop to UIKit for animation
- `swift-performance` -- Animation performance profiling
