import SwiftUI
import UIKit

@MainActor
func copyToPasteboard(_ hex: String, copied: Binding<Bool>) {
    UIPasteboard.general.string = hex
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    withAnimation(.easeInOut(duration: 0.15)) { copied.wrappedValue = true }
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(0.8))
        withAnimation(.easeInOut(duration: 0.15)) { copied.wrappedValue = false }
    }
}
