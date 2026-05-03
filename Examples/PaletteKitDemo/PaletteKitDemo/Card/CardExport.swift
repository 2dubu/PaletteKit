import SwiftUI
import UIKit

/// Renders any SwiftUI view to a UIImage via UIHostingController +
/// UIGraphicsImageRenderer (DESIGN_SPEC §18.5 path A). Validates that
/// SwiftUI shaders / Canvas / Core Image rendering survive the snapshot.
@MainActor
enum CardExport {
    static func snapshot<Content: View>(
        _ content: Content,
        size: CGSize,
        scale: CGFloat = UIScreen.main.scale
    ) -> UIImage {
        let host = UIHostingController(rootView: content.frame(width: size.width, height: size.height))
        host.view.bounds = CGRect(origin: .zero, size: size)
        host.view.backgroundColor = .clear

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
