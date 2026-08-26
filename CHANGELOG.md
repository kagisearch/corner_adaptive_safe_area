## 0.0.2

* Requires Flutter 3.47.0 or later and Dart 3.13.0 or later.
* Supports Swift Package Manager for iOS while retaining CocoaPods compatibility.
* Minimum iOS deployment target: 15.0.

## 0.0.1

* Initial release.
* Minimum iOS deployment target: 13.0.
* Corner-adaptation margins from `UIView.directionalEdgeInsets(for: .margins(cornerAdaptation:))` are read at runtime on iPad devices running iPadOS 26.0+ only; on iPhone, iOS/iPadOS 13.0–25.x, Android phones, Android tablets, and other non-iOS platforms the widgets report `CornerInsets.zero` and render as no-ops.
* `CornerAdaptiveSafeArea` and `CornerAdaptiveBuilder` re-measure once per rendered frame, so animations that move the widget without rebuilding it (`SlideTransition`, `Transform`, `AnimatedBuilder` wrapping a `Transform`) produce up-to-date insets by the end of the animation.
