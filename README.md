# corner_adaptive_safe_area

Per-corner safe-area insets from iPadOS 26's `UIView` corner-adaptation API, exposed as Flutter widgets.

## Why

Flutter's built-in `SafeArea` takes a single rectangle and applies the same four edges everywhere. That works on older hardware, but modern iOS devices have independent hazards at each corner — rounded hardware corners, the Dynamic Island, and, on iPadOS, the floating window controls that appear in Stage Manager and Split View. A uniform inset either wastes space clearing hazards that aren't there, or doesn't clear far enough.

iPadOS 26 exposes this per-corner data on every `UIView` via `directionalEdgeInsets(for: .margins(cornerAdaptation:))`. This package bridges that API to Flutter so widgets can pad only the edges that actually need it, at the corners that actually overlap them.

## Platform support

iOS 15.0 or later for installation. Corner values only populate on iPad devices running iPadOS 26.0+. On iPhone, iOS 15.0–25.x, Android phones, Android tablets, other platforms, and tests without a platform stub, every value is reported as `CornerInsets.zero` and the widgets become effectively no-ops. Android, macOS, web, Windows, and Linux are not implemented.

## Installation

```bash
flutter pub add corner_adaptive_safe_area
```

Your iOS deployment target must be `15.0` or higher (set in `ios/Podfile` and the Runner target). Corner-adaptation values only populate on iPad devices running iPadOS 26.0+; on iPhone, earlier iOS/iPadOS versions, and non-iOS platforms the widgets render as no-ops.

## Setup

Wrap your app once, near the root, in `CornerMarginScope`. It subscribes to the native stream and publishes the live insets down the tree. Every widget from this package reads from it.

```dart
import 'package:corner_adaptive_safe_area/corner_adaptive_safe_area.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) =>
          CornerMarginScope(child: child ?? const SizedBox()),
      home: const HomePage(),
    );
  }
}
```

`MaterialApp.builder` is the canonical place — it sits above every route while still being below `MediaQuery`, which both the scope and the widgets rely on.

## Usage

### Pad a widget by the corners it overlaps

`CornerAdaptiveSafeArea` measures its own rect after layout and pads only the edges that are flush with a window edge whose corner has a non-zero hazard. A widget near the middle of the screen receives no padding. A widget flush to the top-left corner receives `max(topLeft.top, ...)` on top and `max(topLeft.left, ...)` on the left.

```dart
CornerAdaptiveSafeArea(
  child: Container(color: Colors.teal),
)
```

Nesting is safe. An inner `CornerAdaptiveSafeArea` measures itself inside the already-padded outer one, so it sees itself as not flush with the window edges and pads by zero.

### Disable a specific edge

Set `left`, `right`, `top`, or `bottom` to `false` to skip that physical edge even when it is flush. Useful when another widget (a `BottomNavigationBar`, a persistent header) already owns that edge.

```dart
CornerAdaptiveSafeArea(
  bottom: false,
  child: ListView(
    children: const [/* ... */],
  ),
)
```

### Read the insets without applying them

When you need the computed values for something other than padding — sizing an `AppBar.leadingWidth`, laying out a custom navigation bar, shifting a floating action button — use `CornerAdaptiveBuilder`. The builder receives an `EdgeInsets` already resolved for the builder's own rect, same algorithm as `CornerAdaptiveSafeArea`.

```dart
CornerAdaptiveBuilder(
  builder: (context, insets) {
    return AppBar(
      leadingWidth: insets.left + 56,
      title: const Text('Inbox'),
    );
  },
)
```

### Read the raw per-corner values

For advanced cases where you know the rect you care about yourself, read the `InheritedWidget` directly and call `effectiveFor` with your own `Rect`.

```dart
final corners = CornerMargin.of(context);
final windowSize = MediaQuery.sizeOf(context);
final myRect = Offset.zero & const Size(320, 48);

final insets = corners.effectiveFor(myRect, windowSize);
// Or access individual corners:
final topLeftPush = corners.topLeft; // EdgeInsets
```

`CornerMargin.of(context)` returns `CornerInsets.zero` when no scope is installed, so read-paths are safe during widget tests and on platforms without native support.

## How it works

On iOS, the plugin installs four invisible observer views in the Flutter root view, each pinned to one corner and sized at 50% × 50% of the window. Every time one of them lays out — on rotation, Stage Manager resize, Split View change, keyboard appearance — it reads `directionalEdgeInsets(for: .margins(cornerAdaptation: ...))` on itself. Those four readings travel as one snapshot over an event channel to `CornerMarginScope`, which republishes them via `CornerMargin`. `CornerAdaptiveSafeArea` and `CornerAdaptiveBuilder` then intersect their own rect with each corner's hazard rectangle and fold in the values from the corners they overlap.

## API

### `CornerMarginScope`

```dart
const CornerMarginScope({Key? key, required Widget child})
```

Subscribes to the platform stream once and publishes the live `CornerInsets` into the tree via `CornerMargin`. Install once, near the root.

### `CornerMargin`

```dart
static CornerInsets of(BuildContext context)
static CornerInsets? maybeOf(BuildContext context)
```

`InheritedWidget` exposed by `CornerMarginScope`. `of` returns `CornerInsets.zero` when no scope is above; `maybeOf` returns `null`.

### `CornerInsets`

```dart
const CornerInsets({
  EdgeInsets topLeft = EdgeInsets.zero,
  EdgeInsets topRight = EdgeInsets.zero,
  EdgeInsets bottomLeft = EdgeInsets.zero,
  EdgeInsets bottomRight = EdgeInsets.zero,
})

static const CornerInsets zero
EdgeInsets effectiveFor(Rect rect, Size windowSize)
```

Immutable snapshot of the four per-corner pushes. `effectiveFor` computes the `EdgeInsets` that should apply to a widget occupying `rect` inside a window of `windowSize`, by folding in each corner's values whenever the corner's hazard rectangle overlaps `rect`.

### `CornerAdaptiveSafeArea`

```dart
const CornerAdaptiveSafeArea({
  Key? key,
  required Widget child,
  bool left = true,
  bool right = true,
  bool top = true,
  bool bottom = true,
})
```

Measures its own rect after each layout and applies the effective per-corner padding. Set any of `left` / `right` / `top` / `bottom` to `false` to skip that edge even when it is flush with a window edge.

### `CornerAdaptiveBuilder`

```dart
typedef CornerAdaptiveWidgetBuilder = Widget Function(
  BuildContext context,
  EdgeInsets insets,
);

const CornerAdaptiveBuilder({
  Key? key,
  required CornerAdaptiveWidgetBuilder builder,
})
```

Same measurement pipeline as `CornerAdaptiveSafeArea`, but hands the computed `EdgeInsets` to `builder` instead of applying them. Use when you need the values for something other than padding.

### `CornerAdaptiveSafeAreaPlatform`

```dart
static CornerAdaptiveSafeAreaPlatform get instance
static set instance(CornerAdaptiveSafeAreaPlatform instance)

Future<CornerInsets> getInsets()
Stream<CornerInsets> watchInsets()
```

Platform-interface class (via `plugin_platform_interface`). Swap out `instance` in tests or on unsupported platforms. Real apps should never need to touch it.

## Testing

Inject a fake platform so tests don't hit a real method channel:

```dart
import 'package:corner_adaptive_safe_area/corner_adaptive_safe_area.dart';
import 'package:corner_adaptive_safe_area/corner_adaptive_safe_area_platform_interface.dart';

class _FakePlatform extends CornerAdaptiveSafeAreaPlatform {
  _FakePlatform(this._insets);
  final CornerInsets _insets;

  @override
  Future<CornerInsets> getInsets() async => _insets;

  @override
  Stream<CornerInsets> watchInsets() => Stream.value(_insets);
}

void main() {
  testWidgets('pads when corners are non-zero', (tester) async {
    CornerAdaptiveSafeAreaPlatform.instance = _FakePlatform(
      const CornerInsets(
        topLeft: EdgeInsets.only(top: 48, left: 24),
      ),
    );
    // ... pump your widget ...
  });
}
```

See the `test/` directory for worked examples.

## Limitations

- Installs on iOS 15.0+, but corner values only report on iPad devices running iPadOS 26.0+. On iPhone, iOS/iPadOS 15.0–25.x, Android phones, Android tablets, and other non-iOS platforms, `CornerInsets.zero` is reported and the widgets pad by zero.
- No Android, macOS, web, Windows, or Linux implementations.
- `CornerAdaptiveSafeArea` and `CornerAdaptiveBuilder` measure post-layout, so the first frame after a size change may render with stale (or zero) insets before the next frame corrects it.

## License

See [LICENSE](LICENSE).
