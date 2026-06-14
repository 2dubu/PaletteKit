#if canImport(UIKit)
import MetalKit
import UIKit

/// UIKit animated palette gradient. Hosts an `MTKView` and renders a living,
/// LAB-blended multi-point gradient from a ``Palette``. Fills its bounds — mask
/// to any shape with `layer.cornerRadius` or a mask layer, like
/// ``PaletteGraphicView``.
///
/// Honors Reduce Motion and Low Power Mode (holds a static frame) and pauses
/// while off-screen.
public final class AnimatedPaletteGraphicView: UIView {
    private let metalView = MTKView()
    private let renderer = AnimatedPaletteFlowRenderer()
    private var palette: Palette
    private var configuration: AnimatedPaletteGraphic.Configuration

    public init(palette: Palette,
                configuration: AnimatedPaletteGraphic.Configuration = .init()) {
        self.palette = palette
        self.configuration = configuration
        super.init(frame: .zero)

        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.framebufferOnly = true
        metalView.enableSetNeedsDisplay = false
        metalView.isPaused = false
        metalView.delegate = renderer
        metalView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(metalView)
        NSLayoutConstraint.activate([
            metalView.topAnchor.constraint(equalTo: topAnchor),
            metalView.bottomAnchor.constraint(equalTo: bottomAnchor),
            metalView.leadingAnchor.constraint(equalTo: leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        renderer.configure(view: metalView)
        applyConfiguration()

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(refreshMotionState),
                           name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(refreshMotionState),
                           name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Update the palette and/or configuration after creation.
    public func update(palette: Palette? = nil,
                       configuration: AnimatedPaletteGraphic.Configuration? = nil) {
        if let palette { self.palette = palette }
        if let configuration { self.configuration = configuration }
        applyConfiguration()
    }

    private var shouldFreeze: Bool {
        !configuration.isAnimated
            || UIAccessibility.isReduceMotionEnabled
            || ProcessInfo.processInfo.isLowPowerModeEnabled
            || window == nil
            || isHidden
    }

    private func applyConfiguration() {
        renderer.update(
            labColors: configuration.resolveLABColors(from: palette),
            speed: Float(configuration.speed.multiplier),
            frozen: shouldFreeze
        )
    }

    @objc private func refreshMotionState() { applyConfiguration() }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        applyConfiguration()   // pause when leaving the hierarchy, resume when re-added
    }
}
#endif
