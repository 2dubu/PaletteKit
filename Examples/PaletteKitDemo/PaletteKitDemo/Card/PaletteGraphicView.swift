import PaletteKit
import UIKit

/// `PaletteGraphicView` — UIKit pair of ``PaletteGraphic``. Pure UIKit
/// `UIView`; does not host SwiftUI internally. Renders the same Core Image
/// pipeline directly into the layer's contents.
///
/// Set `palette`, `swatches`, or `configuration` at any time and the view
/// re-renders on the next layout pass. Use Auto Layout, sizeToFit, or
/// frame-based layout as you would with any `UIView`.
///
/// ```swift
/// let view = PaletteGraphicView(
///     palette: palette,
///     swatches: swatches,
///     configuration: .init(gradient: .vignette, swatchStrategy: .vibrant, grain: .standard)
/// )
/// view.translatesAutoresizingMaskIntoConstraints = false
/// container.addSubview(view)
/// // …pin with constraints…
/// ```
@MainActor
final class PaletteGraphicView: UIView {
    var palette: Palette {
        didSet { setNeedsRender() }
    }

    var swatches: SwatchMap? {
        didSet { setNeedsRender() }
    }

    var configuration: PaletteGraphic.Configuration {
        didSet { setNeedsRender() }
    }

    private var lastRenderedSize: CGSize = .zero
    private var lastRenderedScale: CGFloat = 0

    init(
        palette: Palette,
        swatches: SwatchMap?,
        configuration: PaletteGraphic.Configuration = .init()
    ) {
        self.palette = palette
        self.swatches = swatches
        self.configuration = configuration
        super.init(frame: .zero)
        backgroundColor = .clear
        layer.contentsGravity = .resize
        isOpaque = false

        // iOS 17+ trait change observer (replaces deprecated
        // `traitCollectionDidChange`). Re-renders when the host's display
        // scale changes, e.g. moving between an external Retina display
        // and a 2x simulator.
        registerForTraitChanges([UITraitDisplayScale.self]) { (view: PaletteGraphicView, _) in
            view.setNeedsRender()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PaletteGraphicView does not support NSCoding")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        renderIfNeeded()
    }

    /// Render synchronously to a `UIImage` at the current bounds. Useful
    /// when the caller wants a snapshot independent of the view's layer.
    func snapshotImage(scale: CGFloat? = nil) -> UIImage? {
        let resolvedScale = scale ?? traitCollection.displayScale
        let pixelSize = CGSize(
            width: max(bounds.width * resolvedScale, 1),
            height: max(bounds.height * resolvedScale, 1)
        )
        guard let cg = PaletteGraphicRenderer.makeCGImage(
            palette: palette,
            swatches: swatches,
            configuration: configuration,
            pixelSize: pixelSize
        ) else { return nil }
        return UIImage(cgImage: cg, scale: resolvedScale, orientation: .up)
    }

    private func setNeedsRender() {
        lastRenderedSize = .zero
        setNeedsLayout()
    }

    private func renderIfNeeded() {
        let scale = traitCollection.displayScale
        let pixelSize = CGSize(
            width: max(bounds.width * scale, 1),
            height: max(bounds.height * scale, 1)
        )
        guard pixelSize.width > 0, pixelSize.height > 0 else { return }
        guard pixelSize != lastRenderedSize || scale != lastRenderedScale else { return }

        if let cg = PaletteGraphicRenderer.makeCGImage(
            palette: palette,
            swatches: swatches,
            configuration: configuration,
            pixelSize: pixelSize
        ) {
            layer.contents = cg
            layer.contentsScale = scale
            lastRenderedSize = pixelSize
            lastRenderedScale = scale
        }
    }
}
