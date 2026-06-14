import PaletteKit
import SwiftUI

/// Playground for ``AnimatedPaletteGraphic`` — tweak color count, speed, and the
/// animated toggle on the extracted palette.
struct AnimatedLabView: View {
    let palette: Palette

    @State private var colorCount: ColorCount = .three
    @State private var speed: FlowSpeed = .regular
    @State private var isAnimated = true

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AnimatedPaletteGraphic(
                    palette: palette,
                    configuration: .init(
                        colorCount: colorCount,
                        speed: speed,
                        isAnimated: isAnimated
                    )
                )
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal)

                colorCountPicker
                speedPicker
                Toggle("Animated", isOn: $isAnimated)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Animated")
    }

    private var colorCountPicker: some View {
        Picker("Colors", selection: $colorCount) {
            Text("2").tag(ColorCount.two)
            Text("3").tag(ColorCount.three)
            Text("4").tag(ColorCount.four)
            Text("5").tag(ColorCount.five)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private var speedPicker: some View {
        Picker("Speed", selection: $speed) {
            Text("Slow").tag(FlowSpeed.slow)
            Text("Regular").tag(FlowSpeed.regular)
            Text("Fast").tag(FlowSpeed.fast)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}
