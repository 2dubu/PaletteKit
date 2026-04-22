import Foundation

public struct SwatchClassifier: Sendable {
    public init() {}

    public func classify(palette: Palette) -> SwatchMap {
        let colors = palette.colors
        guard !colors.isEmpty else { return SwatchMap() }

        let maxPopulation = max(colors.map(\.population).max() ?? 1, 1)

        struct Assignment {
            let role: SwatchRole
            let color: PaletteColor
            let score: Double
        }

        var ranked: [Assignment] = []
        for target in Self.targets {
            var bestScore = -Double.infinity
            var bestColor: PaletteColor?
            for color in colors {
                let score = Self.score(color: color, target: target, maxPopulation: maxPopulation)
                if score > bestScore {
                    bestScore = score
                    bestColor = color
                }
            }
            if let bestColor, bestScore > -.infinity {
                ranked.append(Assignment(role: target.role, color: bestColor, score: bestScore))
            }
        }

        ranked.sort { $0.score > $1.score }

        var used = Set<PaletteColor>()
        var resolved: [SwatchRole: Swatch] = [:]

        for assignment in ranked {
            if used.contains(assignment.color) {
                if let fallback = Self.nextBestColor(
                    for: assignment.role,
                    colors: colors,
                    used: used,
                    maxPopulation: maxPopulation
                ) {
                    used.insert(fallback)
                    resolved[assignment.role] = Self.makeSwatch(fallback, role: assignment.role)
                }
            } else {
                used.insert(assignment.color)
                resolved[assignment.role] = Self.makeSwatch(assignment.color, role: assignment.role)
            }
        }

        return SwatchMap(
            vibrant: resolved[.vibrant],
            muted: resolved[.muted],
            darkVibrant: resolved[.darkVibrant],
            darkMuted: resolved[.darkMuted],
            lightVibrant: resolved[.lightVibrant],
            lightMuted: resolved[.lightMuted]
        )
    }

    private static let weightL = 6.0
    private static let weightC = 3.0
    private static let weightPop = 1.0

    private struct Target {
        let role: SwatchRole
        let targetL: Double
        let minL: Double
        let maxL: Double
        let targetC: Double
        let minC: Double
    }

    private static let targets: [Target] = [
        Target(role: .vibrant, targetL: 0.65, minL: 0.40, maxL: 0.85, targetC: 0.20, minC: 0.08),
        Target(role: .muted, targetL: 0.65, minL: 0.40, maxL: 0.85, targetC: 0.04, minC: 0.00),
        Target(role: .darkVibrant, targetL: 0.30, minL: 0.00, maxL: 0.45, targetC: 0.20, minC: 0.08),
        Target(role: .darkMuted, targetL: 0.30, minL: 0.00, maxL: 0.45, targetC: 0.04, minC: 0.00),
        Target(role: .lightVibrant, targetL: 0.85, minL: 0.70, maxL: 1.00, targetC: 0.20, minC: 0.08),
        Target(role: .lightMuted, targetL: 0.85, minL: 0.70, maxL: 1.00, targetC: 0.04, minC: 0.00),
    ]

    private static func score(
        color: PaletteColor,
        target: Target,
        maxPopulation: Int
    ) -> Double {
        let lch = color.oklch
        if lch.l < target.minL || lch.l > target.maxL { return -.infinity }
        if lch.c < target.minC { return -.infinity }

        let lightnessCloseness = 1 - abs(lch.l - target.targetL)
        let chromaCloseness = 1 - min(abs(lch.c - target.targetC) / 0.2, 1)
        let populationShare = maxPopulation > 0
            ? Double(color.population) / Double(maxPopulation)
            : 0
        return lightnessCloseness * weightL
            + chromaCloseness * weightC
            + populationShare * weightPop
    }

    private static func nextBestColor(
        for role: SwatchRole,
        colors: [PaletteColor],
        used: Set<PaletteColor>,
        maxPopulation: Int
    ) -> PaletteColor? {
        guard let target = targets.first(where: { $0.role == role }) else { return nil }
        var best: (color: PaletteColor, score: Double)?
        for color in colors where !used.contains(color) {
            let candidateScore = score(color: color, target: target, maxPopulation: maxPopulation)
            if candidateScore > (best?.score ?? -.infinity), candidateScore > -.infinity {
                best = (color, candidateScore)
            }
        }
        return best?.color
    }

    private static func makeSwatch(_ color: PaletteColor, role: SwatchRole) -> Swatch {
        let textColor = color.textColor
        return Swatch(
            color: color,
            role: role,
            titleTextColor: textColor,
            bodyTextColor: textColor
        )
    }
}
