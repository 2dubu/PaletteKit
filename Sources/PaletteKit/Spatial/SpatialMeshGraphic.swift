#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// Experimental adapter. Uses the oriented input aspect ratio by default.
@_spi(SpatialPrototype)
@available(iOS 18.0, *)
public struct SpatialMeshGraphic: View {
    public let mesh: SpatialMesh

    public init(mesh: SpatialMesh) { self.mesh = mesh }

    public var body: some View {
        MeshGradient(width: mesh.grid.rawValue, height: mesh.grid.rawValue,
                     points: mesh.points, colors: mesh.colors.map { Color(UIColor($0)) })
            .aspectRatio(mesh.aspectRatio, contentMode: .fit)
    }

    /// Exports at the original display aspect ratio; `width` is in points.
    @MainActor
    public func makeImage(width: CGFloat, scale: CGFloat = 2) -> UIImage? {
        guard width.isFinite, scale.isFinite, width > 0, scale > 0 else { return nil }
        let renderer = ImageRenderer(content: self.frame(width: width, height: width / mesh.aspectRatio))
        renderer.scale = scale
        return renderer.uiImage
    }
}
#endif
