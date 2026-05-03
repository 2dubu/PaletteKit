import PaletteKit
import SwiftUI
import UIKit

struct CardLabView: View {
    let palette: Palette
    let swatches: SwatchMap?

    @State private var direction: GradientDirection = .linear
    @State private var axis: LabAxis = .bottomLeftToTopRight
    @State private var colorCount: ColorCount = .two
    @State private var strategy: SwatchStrategy = .vibrant
    @State private var shape: LabShape = .rectangle
    @State private var grain: GrainStyle = .standard
    @State private var shareImage: UIImage?
    @State private var showShare = false

    /// Demo-only — picker selection driving which `Shape` is applied via
    /// `.clipShape(...)` after `PaletteGraphic`. Real consumers pass any
    /// SwiftUI `Shape` directly to `.clipShape`.
    enum LabShape: String, CaseIterable, Identifiable {
        case circle = "Circle"
        case rectangle = "Rectangle"

        var id: String { rawValue }
    }

    /// Demo-only — preset axis directions for the linear gradient picker.
    /// Real consumers pass any `UnitPoint` pair to `Configuration.linearStart`
    /// / `linearEnd`.
    enum LabAxis: String, CaseIterable, Identifiable {
        case bottomLeftToTopRight = "↗"
        case topLeftToBottomRight = "↘"
        case leftToRight          = "→"
        case topToBottom          = "↓"

        var id: String { rawValue }

        var start: UnitPoint {
            switch self {
            case .bottomLeftToTopRight: return .bottomLeading
            case .topLeftToBottomRight: return .topLeading
            case .leftToRight:          return .leading
            case .topToBottom:          return .top
            }
        }
        var end: UnitPoint {
            switch self {
            case .bottomLeftToTopRight: return .topTrailing
            case .topLeftToBottomRight: return .bottomTrailing
            case .leftToRight:          return .trailing
            case .topToBottom:          return .bottom
            }
        }
    }

    private var configuration: PaletteGraphic.Configuration {
        .init(
            direction: direction,
            linearStart: axis.start,
            linearEnd: axis.end,
            colorCount: colorCount,
            swatchStrategy: strategy,
            grain: grain
        )
    }

    private var cardPalette: CardPalette {
        CardPalette(palette: palette, swatches: swatches, strategy: strategy)
    }

    var body: some View {
        let cp = cardPalette
        VStack(spacing: 12) {
            directionPicker
                .padding(.horizontal, 16)
                .padding(.top, 12)

            if direction == .linear {
                axisPicker
                    .padding(.horizontal, 16)
            }

            stopsPicker
                .padding(.horizontal, 16)

            strategyPicker
                .padding(.horizontal, 16)

            shapePicker
                .padding(.horizontal, 16)

            grainPicker
                .padding(.horizontal, 16)

            graphicArea(cp: cp)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            swatchChipBar(cp: cp)
                .padding(.horizontal, 24)

            footerLabel(cp: cp)
                .padding(.horizontal, 24)
                .padding(.bottom, 14)
        }
        .background(Color(cp.background).opacity(0.55).ignoresSafeArea())
        .navigationTitle("Graphic Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await captureAndShare() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share PNG")
            }
        }
        .sheet(isPresented: $showShare) {
            if let shareImage {
                ShareSheet(items: [shareImage])
            }
        }
    }

    private var directionPicker: some View {
        Picker("Direction", selection: $direction) {
            ForEach(GradientDirection.allCases) { d in Text(d.rawValue).tag(d) }
        }
        .pickerStyle(.segmented)
    }

    private var axisPicker: some View {
        Picker("Axis", selection: $axis) {
            ForEach(LabAxis.allCases) { a in Text(a.rawValue).tag(a) }
        }
        .pickerStyle(.segmented)
    }

    private var stopsPicker: some View {
        Picker("Colors", selection: $colorCount) {
            ForEach(ColorCount.allCases) { c in Text("\(c.rawValue)").tag(c) }
        }
        .pickerStyle(.segmented)
    }

    private var strategyPicker: some View {
        Picker("Strategy", selection: $strategy) {
            ForEach(SwatchStrategy.allCases) { s in Text(s.rawValue).tag(s) }
        }
        .pickerStyle(.segmented)
    }

    private var shapePicker: some View {
        Picker("Shape", selection: $shape) {
            ForEach(LabShape.allCases) { s in Text(s.rawValue).tag(s) }
        }
        .pickerStyle(.segmented)
    }

    private var grainPicker: some View {
        Picker("Grain", selection: $grain) {
            ForEach(GrainStyle.allCases) { s in Text(s.rawValue).tag(s) }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private func graphicArea(cp: CardPalette) -> some View {
        let graphic = PaletteGraphic(palette: palette, swatches: swatches, configuration: configuration)
            .aspectRatio(1.0, contentMode: .fit)

        Group {
            switch shape {
            case .circle:    graphic.clipShape(Circle())
            case .rectangle: graphic.clipShape(Rectangle())
            }
        }
        .padding(.horizontal, 36)
        .shadow(color: Color(cp.edge).opacity(0.18), radius: 18, x: 0, y: 12)
    }

    private func swatchChipBar(cp: CardPalette) -> some View {
        HStack(spacing: 8) {
            chip(label: "center", color: cp.center, cp: cp)
            chip(label: "edge", color: cp.edge, cp: cp)
            chip(label: "bg", color: cp.background, cp: cp)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func chip(label: String, color: PaletteColor, cp: CardPalette) -> some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(color))
                .frame(width: 44, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
                )
            Text(color.hex)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color(cp.accent).opacity(0.6))
            Text(label)
                .font(.system(size: 8, design: .rounded))
                .foregroundStyle(Color(cp.accent).opacity(0.45))
        }
    }

    private func footerLabel(cp: CardPalette) -> some View {
        VStack(spacing: 2) {
            Text("\(direction.rawValue) · \(strategy.rawValue) · \(grain.rawValue)")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(cp.accent).opacity(0.85))
            Text(direction.subtitle)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color(cp.accent).opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @MainActor
    private func captureAndShare() async {
        let size = CGSize(width: 1080, height: 1350)
        let baseGraphic = PaletteGraphic(palette: palette, swatches: swatches, configuration: configuration)
            .frame(width: size.width, height: size.height)
        switch shape {
        case .circle:
            shareImage = CardExport.snapshot(baseGraphic.clipShape(Circle()), size: size)
        case .rectangle:
            shareImage = CardExport.snapshot(baseGraphic.clipShape(Rectangle()), size: size)
        }
        showShare = true
    }
}

private extension GradientDirection {
    var subtitle: String {
        switch self {
        case .linear: return "diagonal flow"
        case .radial: return "off-center radial"
        }
    }
}
