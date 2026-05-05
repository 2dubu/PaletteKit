#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI

/// Cross-fade transition applied when ``AsyncPaletteGraphic`` resolves
/// asynchronously (cache miss). Cache hits skip the transition.
///
/// Set on a SwiftUI subtree via ``SwiftUI/View/asyncPaletteGraphicTransition(_:)``.
/// UIKit consumers configure ``AsyncPaletteGraphicView/transition`` directly.
public struct AsyncPaletteGraphicTransition: Equatable, Sendable {
    public let animation: Animation
    public let duration: TimeInterval

    private init(animation: Animation, duration: TimeInterval) {
        self.animation = animation
        self.duration = duration
    }

    /// 0.20s linear cross-fade. Default when no modifier is set.
    public static let normal: Self = .init(animation: .linear(duration: 0.20), duration: 0.20)

    /// 0.35s linear cross-fade.
    public static let slow: Self = .init(animation: .linear(duration: 0.35), duration: 0.35)

    /// 0.50s linear cross-fade.
    public static let extraSlow: Self = .init(animation: .linear(duration: 0.50), duration: 0.50)

    /// Custom animation. The reported `duration` falls back to 0.20s when
    /// the underlying `Animation` does not expose a numeric duration; this
    /// only affects UIKit's `UIView.transition(...)` timing fallback.
    public static func custom(_ animation: Animation,
                              duration: TimeInterval = 0.20) -> Self {
        .init(animation: animation, duration: duration)
    }
}

extension EnvironmentValues {
    /// Cross-fade transition applied to ``AsyncPaletteGraphic`` resolutions
    /// in this subtree. Set with
    /// ``SwiftUI/View/asyncPaletteGraphicTransition(_:)``. Default ``AsyncPaletteGraphicTransition/normal``.
    @Entry public var asyncPaletteGraphicTransition: AsyncPaletteGraphicTransition? = .normal
}

extension View {
    /// Configure the cross-fade transition for ``AsyncPaletteGraphic`` views
    /// in this subtree. Pass `nil` to disable transitions entirely.
    public func asyncPaletteGraphicTransition(_ transition: AsyncPaletteGraphicTransition?) -> some View {
        environment(\.asyncPaletteGraphicTransition, transition)
    }
}
#endif
