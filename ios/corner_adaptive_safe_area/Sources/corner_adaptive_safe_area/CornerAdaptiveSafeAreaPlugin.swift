import Flutter
import UIKit

// Bridges iPadOS 26 corner-adaptation margins to Flutter by installing four
// invisible quadrant views in the Flutter root view, each pinned via Auto
// Layout to cover one quarter of the window (aligned to its corner, sized
// at 50% × 50%). Each quadrant's `directionalEdgeInsets(for: .margins(
// cornerAdaptation:))` reports the push required to clear that specific
// corner's hazard (window controls, hardware rounding). All four values
// travel through one event channel as `{topLeft, topRight, bottomLeft,
// bottomRight}` so Flutter widgets can reason about each corner
// independently.
public class CornerAdaptiveSafeAreaPlugin: NSObject, FlutterPlugin {

  private static let methodChannelName = "corner_adaptive_safe_area"
  private static let eventChannelName = "corner_adaptive_safe_area/insets"

  private let streamHandler = InsetsStreamHandler()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = CornerAdaptiveSafeAreaPlugin()

    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: methodChannel)

    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: registrar.messenger()
    )
    eventChannel.setStreamHandler(instance.streamHandler)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "getInsets":
      let snapshot = streamHandler.snapshot()
      result(InsetsResolver.toMap(snapshot))
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

enum Corner: String, CaseIterable {
  case topLeft
  case topRight
  case bottomLeft
  case bottomRight
}

// Rolled-up per-corner insets. Each corner reports the directional edge
// insets from ITS view's edges to the margins layout region — but only the
// two edges that face outward (toward the window corner) carry useful
// values; the inward edges face the centre and are typically zero.
struct CornerInsetsSnapshot: Equatable {
  var insets: [Corner: NSDirectionalEdgeInsets] = [:]

  static let zero = CornerInsetsSnapshot(
    insets: Dictionary(uniqueKeysWithValues: Corner.allCases.map { ($0, .zero) })
  )
}

enum InsetsResolver {

  @available(iOS 26.0, *)
  static func insets(for view: UIView) -> NSDirectionalEdgeInsets {
    // max(horizontal, vertical) per edge — the quadrant view's worst-case
    // push along each axis of flow. Matches the single-stream semantics we
    // had before, just scoped to this quadrant.
    let h = view.directionalEdgeInsets(for: .margins(cornerAdaptation: .horizontal))
    let v = view.directionalEdgeInsets(for: .margins(cornerAdaptation: .vertical))
    return NSDirectionalEdgeInsets(
      top: max(h.top, v.top),
      leading: max(h.leading, v.leading),
      bottom: max(h.bottom, v.bottom),
      trailing: max(h.trailing, v.trailing)
    )
  }

  static func toMap(_ snapshot: CornerInsetsSnapshot) -> [String: [String: Double]] {
    var out: [String: [String: Double]] = [:]
    for corner in Corner.allCases {
      let i = snapshot.insets[corner] ?? .zero
      out[corner.rawValue] = [
        "top": Double(i.top),
        "leading": Double(i.leading),
        "trailing": Double(i.trailing),
        "bottom": Double(i.bottom),
      ]
    }
    return out
  }

  static func keyRootView() -> UIView? {
    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else { continue }
      if let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first {
        return window.rootViewController?.view
      }
    }
    return nil
  }

  static var supportsCornerInsets: Bool {
    guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
    if #available(iOS 26.0, *) { return true }
    return false
  }
}

// Owns the four quadrant observer views and forwards insets whenever any
// of them lays out.
final class InsetsStreamHandler: NSObject, FlutterStreamHandler {

  private var sink: FlutterEventSink?
  private var quadrantViews: [Corner: LayoutObserverView] = [:]
  private var attachedRoot: UIView?
  private var lastSnapshot: CornerInsetsSnapshot?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    guard InsetsResolver.supportsCornerInsets else {
      emitIfChanged(force: true)
      return nil
    }

    attachWithRetry(remainingAttempts: 10)
    emitIfChanged(force: true)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(sceneChanged),
      name: UIScene.didActivateNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(sceneChanged),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(sceneChanged),
      name: UIWindow.didBecomeVisibleNotification,
      object: nil
    )
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    quadrantViews.values.forEach { $0.removeFromSuperview() }
    quadrantViews.removeAll()
    attachedRoot = nil
    lastSnapshot = nil
    NotificationCenter.default.removeObserver(self)
    return nil
  }

  func snapshot() -> CornerInsetsSnapshot {
    guard InsetsResolver.supportsCornerInsets else { return .zero }

    if #available(iOS 26.0, *) {
      var insets: [Corner: NSDirectionalEdgeInsets] = [:]
      for (corner, view) in quadrantViews {
        insets[corner] = InsetsResolver.insets(for: view)
      }
      // Fill missing corners with zero to keep the snapshot complete.
      for corner in Corner.allCases where insets[corner] == nil {
        insets[corner] = .zero
      }
      return CornerInsetsSnapshot(insets: insets)
    }

    return .zero
  }

  @objc private func sceneChanged() {
    _ = attach()
    emitIfChanged(force: true)
  }

  private func attach() -> Bool {
    guard let root = InsetsResolver.keyRootView() else { return false }
    if attachedRoot === root, !quadrantViews.isEmpty { return true }

    quadrantViews.values.forEach { $0.removeFromSuperview() }
    quadrantViews.removeAll()

    for corner in Corner.allCases {
      let view = LayoutObserverView(corner: corner)
      view.translatesAutoresizingMaskIntoConstraints = false
      view.isUserInteractionEnabled = false
      view.backgroundColor = .clear
      view.onLayout = { [weak self] in self?.emitIfChanged(force: false) }
      root.insertSubview(view, at: 0)
      quadrantViews[corner] = view
    }

    NSLayoutConstraint.activate(Self.constraints(for: quadrantViews, in: root))
    attachedRoot = root

    // iPadOS layout evolves across multiple passes after insertion; the
    // quadrant views' own bounds settle early but parent-driven inputs to
    // `.margins(cornerAdaptation:)` can keep changing. Force a layout pass
    // and re-read on the next runloop so the post-settlement snapshot isn't
    // missed.
    DispatchQueue.main.async { [weak self] in
      self?.attachedRoot?.layoutIfNeeded()
      self?.emitIfChanged(force: false)
    }

    return true
  }

  private func attachWithRetry(remainingAttempts: Int) {
    if attach() {
      emitIfChanged(force: true)
      return
    }
    guard remainingAttempts > 0 else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      guard self?.sink != nil else { return }
      self?.attachWithRetry(remainingAttempts: remainingAttempts - 1)
    }
  }

  private func emitIfChanged(force: Bool) {
    guard let sink = sink else { return }
    let snap = snapshot()
    if !force, let last = lastSnapshot, last == snap { return }
    lastSnapshot = snap
    sink(InsetsResolver.toMap(snap))
  }

  // Four constraints per quadrant: anchored to its corner of the root,
  // sized at 50% × 50% of the root. Re-evaluated automatically on layout.
  private static func constraints(
    for views: [Corner: LayoutObserverView],
    in root: UIView
  ) -> [NSLayoutConstraint] {
    var cs: [NSLayoutConstraint] = []
    for (corner, v) in views {
      cs.append(v.widthAnchor.constraint(equalTo: root.widthAnchor, multiplier: 0.5))
      cs.append(v.heightAnchor.constraint(equalTo: root.heightAnchor, multiplier: 0.5))
      switch corner {
      case .topLeft:
        cs.append(v.topAnchor.constraint(equalTo: root.topAnchor))
        cs.append(v.leadingAnchor.constraint(equalTo: root.leadingAnchor))
      case .topRight:
        cs.append(v.topAnchor.constraint(equalTo: root.topAnchor))
        cs.append(v.trailingAnchor.constraint(equalTo: root.trailingAnchor))
      case .bottomLeft:
        cs.append(v.bottomAnchor.constraint(equalTo: root.bottomAnchor))
        cs.append(v.leadingAnchor.constraint(equalTo: root.leadingAnchor))
      case .bottomRight:
        cs.append(v.bottomAnchor.constraint(equalTo: root.bottomAnchor))
        cs.append(v.trailingAnchor.constraint(equalTo: root.trailingAnchor))
      }
    }
    return cs
  }
}

// Forwards every `layoutSubviews` call into a closure. One instance per
// corner; the closure re-polls all four and pushes an update if anything
// changed. KVO on UIView bounds is unreliable for iPadOS 26 window
// resize, so we rely on `layoutSubviews` which is contractual.
private final class LayoutObserverView: UIView {
  let corner: Corner
  var onLayout: (() -> Void)?

  init(corner: Corner) {
    self.corner = corner
    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func layoutSubviews() {
    super.layoutSubviews()
    onLayout?()
  }

  // `.margins(cornerAdaptation:)` derives from safeAreaInsets and
  // layoutMargins. Those can change on iPadOS (rotation, Stage Manager,
  // Split View) without the quadrant view's own bounds changing, so
  // layoutSubviews alone misses the post-settlement update.
  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    onLayout?()
  }

  override func layoutMarginsDidChange() {
    super.layoutMarginsDidChange()
    onLayout?()
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    onLayout?()
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

extension NSDirectionalEdgeInsets {
  public static func == (lhs: NSDirectionalEdgeInsets, rhs: NSDirectionalEdgeInsets) -> Bool {
    lhs.top == rhs.top && lhs.leading == rhs.leading &&
    lhs.trailing == rhs.trailing && lhs.bottom == rhs.bottom
  }
}
