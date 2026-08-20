import Foundation

public struct MmcqQuantizer: Quantizer {
    public let name = "MMCQ-CPU"

    public init() {}

    public func prepare() async throws {}

    public func quantize(
        pixels: [PixelTriplet],
        maxColors: Int
    ) async throws -> [QuantizedColor] {
        try Task.checkCancellation()
        return try MmcqEngine.quantize(pixels: pixels, maxColors: maxColors)
    }
}

enum MmcqEngine {
    static let sigBits = 5
    static let rShift = 8 - sigBits
    static let maxIterations = 1_000
    static let fractByPopulation = 0.75
    static let histSize = 1 << (3 * sigBits)

    @inline(__always)
    static func colorIndex(_ r: Int, _ g: Int, _ b: Int) -> Int {
        (r << (2 * sigBits)) + (g << sigBits) + b
    }

    static func quantize(
        pixels: [PixelTriplet],
        maxColors: Int,
        providedHistogram: [UInt32]? = nil
    ) throws -> [QuantizedColor] {
        guard !pixels.isEmpty, maxColors >= 2, maxColors <= 256 else { return [] }

        if let shortCircuit = try shortCircuitUniqueColors(pixels: pixels, maxColors: maxColors) {
            return shortCircuit
        }

        let histogram: [UInt32]
        if let providedHistogram, providedHistogram.count == histSize {
            histogram = providedHistogram
        } else {
            var working = [UInt32](repeating: 0, count: histSize)
            for pixel in pixels {
                let r = Int(pixel.r) >> rShift
                let g = Int(pixel.g) >> rShift
                let b = Int(pixel.b) >> rShift
                working[colorIndex(r, g, b)] &+= 1
            }
            histogram = working
        }

        let initialBox = try VBox.from(pixels: pixels)
        var queue = PQueue<VBox>(compare: { $0.count(histogram: histogram) < $1.count(histogram: histogram) })
        queue.push(initialBox)

        let phase1Target = Int((Double(maxColors) * fractByPopulation).rounded(.up))
        try iterate(queue: &queue, target: phase1Target, histogram: histogram)

        var queue2 = PQueue<VBox>(compare: { a, b in
            let ap = a.count(histogram: histogram) * a.volume()
            let bp = b.count(histogram: histogram) * b.volume()
            return ap < bp
        })
        while !queue.isEmpty {
            queue2.push(queue.pop()!)
        }
        try iterate(queue: &queue2, target: maxColors, histogram: histogram)

        var results: [QuantizedColor] = []
        results.reserveCapacity(queue2.size)
        while let box = queue2.pop() {
            let avg = box.average(histogram: histogram)
            results.append(
                QuantizedColor(
                    color: PixelTriplet(r: avg.r, g: avg.g, b: avg.b),
                    population: box.count(histogram: histogram)
                )
            )
        }
        return results
    }

    private static func iterate(
        queue: inout PQueue<VBox>,
        target: Int,
        histogram: [UInt32]
    ) throws {
        var iterations = 0
        var unsplittable: [VBox] = []
        defer {
            for box in unsplittable {
                queue.push(box)
            }
        }

        while iterations < maxIterations {
            if queue.size + unsplittable.count >= target { return }
            iterations += 1
            try Task.checkCancellation()

            guard let box = queue.pop() else { return }
            guard box.count(histogram: histogram) > 0 else {
                assertionFailure("MMCQ queued a VBox with no histogram population")
                continue
            }

            guard let split = medianCut(histogram: histogram, box: box) else {
                // Keep valid terminal boxes in the result, but remove them from
                // the active queue so they do not consume the iteration budget.
                unsplittable.append(box)
                continue
            }
            queue.push(split.0)
            queue.push(split.1)
        }
    }

    private static func shortCircuitUniqueColors(
        pixels: [PixelTriplet],
        maxColors: Int
    ) throws -> [QuantizedColor]? {
        var counts: [PixelTriplet: Int] = [:]
        counts.reserveCapacity(min(pixels.count, maxColors + 1))
        for pixel in pixels {
            counts[pixel, default: 0] += 1
            if counts.count > maxColors { return nil }
        }

        try Task.checkCancellation()
        return counts
            .map { QuantizedColor(color: $0.key, population: $0.value) }
            .sorted { $0.population > $1.population }
    }

    private static func medianCut(histogram: [UInt32], box: VBox) -> (VBox, VBox)? {
        let count = box.count(histogram: histogram)
        guard count > 1 else { return nil }

        // Prefer the widest axis to preserve MMCQ's normal output, but fall
        // back when that axis contains only one occupied coordinate. This can
        // happen after an earlier cut leaves empty geometric space in a child.
        for cutAxis in axesByDescendingWidth(box: box) {
            let (lo, hi) = axisRange(box: box, axis: cutAxis)
            guard lo < hi else { continue }

            let (partial, total) = partialSums(histogram: histogram, box: box, axis: cutAxis)
            guard total > 0 else { continue }
            guard let pivot = (lo...hi).first(where: { partial[$0] > total / 2 }) else {
                continue
            }
            guard
                let splitPoint = findSplitPoint(
                    partial: partial,
                    total: total,
                    range: lo...hi,
                    pivot: pivot
                )
            else {
                continue
            }

            var first = box
            var second = box
            switch cutAxis {
            case .r:
                first.r2 = splitPoint
                second.r1 = splitPoint + 1
            case .g:
                first.g2 = splitPoint
                second.g1 = splitPoint + 1
            case .b:
                first.b2 = splitPoint
                second.b1 = splitPoint + 1
            }
            first.invalidateCaches()
            second.invalidateCaches()
            return (first, second)
        }
        return nil
    }

    private static func partialSums(
        histogram: [UInt32],
        box: VBox,
        axis: Axis
    ) -> (partial: [Int], total: Int) {
        // Partial sums are indexed by one 5-bit channel, not by the full RGB
        // histogram index.
        var partial = [Int](repeating: 0, count: 1 << sigBits)
        var total = 0

        switch axis {
        case .r:
            for i in box.r1...box.r2 {
                var sum = 0
                for j in box.g1...box.g2 {
                    for k in box.b1...box.b2 {
                        sum += Int(histogram[colorIndex(i, j, k)])
                    }
                }
                total += sum
                partial[i] = total
            }
        case .g:
            for i in box.g1...box.g2 {
                var sum = 0
                for j in box.r1...box.r2 {
                    for k in box.b1...box.b2 {
                        sum += Int(histogram[colorIndex(j, i, k)])
                    }
                }
                total += sum
                partial[i] = total
            }
        case .b:
            for i in box.b1...box.b2 {
                var sum = 0
                for j in box.r1...box.r2 {
                    for k in box.g1...box.g2 {
                        sum += Int(histogram[colorIndex(j, k, i)])
                    }
                }
                total += sum
                partial[i] = total
            }
        }

        return (partial, total)
    }

    private static func axisRange(box: VBox, axis: Axis) -> (Int, Int) {
        switch axis {
        case .r: return (box.r1, box.r2)
        case .g: return (box.g1, box.g2)
        case .b: return (box.b1, box.b2)
        }
    }

    private static func axesByDescendingWidth(box: VBox) -> [Axis] {
        [
            (axis: Axis.r, width: box.r2 - box.r1 + 1, order: 0),
            (axis: Axis.g, width: box.g2 - box.g1 + 1, order: 1),
            (axis: Axis.b, width: box.b2 - box.b1 + 1, order: 2),
        ]
        .sorted { lhs, rhs in
            if lhs.width == rhs.width { return lhs.order < rhs.order }
            return lhs.width > rhs.width
        }
        .map { $0.axis }
    }

    private static func findSplitPoint(
        partial: [Int],
        total: Int,
        range: ClosedRange<Int>,
        pivot: Int
    ) -> Int? {
        guard range.lowerBound < range.upperBound else { return nil }

        let left = pivot - range.lowerBound
        let right = range.upperBound - pivot
        let preferred: Int
        if left <= right {
            preferred = min(range.upperBound - 1, pivot + right / 2)
        } else {
            preferred = max(range.lowerBound, pivot - 1 - left / 2)
        }

        // A cut after `candidate` is valid only when both children contain
        // pixels. Choosing the closest valid boundary preserves the existing
        // geometric bias without ever creating an empty or inverted VBox.
        var best: Int?
        var bestDistance = Int.max
        for candidate in range.lowerBound..<range.upperBound {
            let firstCount = partial[candidate]
            let secondCount = total - firstCount
            guard firstCount > 0, secondCount > 0 else { continue }

            let distance = abs(candidate - preferred)
            if distance < bestDistance {
                best = candidate
                bestDistance = distance
            }
        }
        return best
    }

    private enum Axis { case r, g, b }

    struct VBox {
        var r1: Int
        var r2: Int
        var g1: Int
        var g2: Int
        var b1: Int
        var b2: Int
        private var cachedCount: Int?
        private var cachedVolume: Int?

        init(r1: Int, r2: Int, g1: Int, g2: Int, b1: Int, b2: Int) {
            self.r1 = r1
            self.r2 = r2
            self.g1 = g1
            self.g2 = g2
            self.b1 = b1
            self.b2 = b2
        }

        static func from(pixels: [PixelTriplet]) throws -> VBox {
            var rMin = Int.max, rMax = 0
            var gMin = Int.max, gMax = 0
            var bMin = Int.max, bMax = 0
            for pixel in pixels {
                let r = Int(pixel.r) >> MmcqEngine.rShift
                let g = Int(pixel.g) >> MmcqEngine.rShift
                let b = Int(pixel.b) >> MmcqEngine.rShift
                rMin = min(rMin, r); rMax = max(rMax, r)
                gMin = min(gMin, g); gMax = max(gMax, g)
                bMin = min(bMin, b); bMax = max(bMax, b)
            }
            return VBox(r1: rMin, r2: rMax, g1: gMin, g2: gMax, b1: bMin, b2: bMax)
        }

        mutating func invalidateCaches() {
            cachedCount = nil
            cachedVolume = nil
        }

        func volume() -> Int {
            (r2 - r1 + 1) * (g2 - g1 + 1) * (b2 - b1 + 1)
        }

        func count(histogram: [UInt32]) -> Int {
            if let cached = cachedCount { return cached }
            var npix = 0
            for i in r1...r2 {
                for j in g1...g2 {
                    for k in b1...b2 {
                        npix += Int(histogram[MmcqEngine.colorIndex(i, j, k)])
                    }
                }
            }
            return npix
        }

        func average(histogram: [UInt32]) -> RGB {
            let mult = 1 << MmcqEngine.rShift

            if r1 == r2, g1 == g2, b1 == b2 {
                return RGB(
                    r: UInt8(min(255, r1 << MmcqEngine.rShift)),
                    g: UInt8(min(255, g1 << MmcqEngine.rShift)),
                    b: UInt8(min(255, b1 << MmcqEngine.rShift))
                )
            }

            var ntot = 0
            var rSum = 0.0
            var gSum = 0.0
            var bSum = 0.0

            for i in r1...r2 {
                for j in g1...g2 {
                    for k in b1...b2 {
                        let value = Int(histogram[MmcqEngine.colorIndex(i, j, k)])
                        if value == 0 { continue }
                        ntot += value
                        rSum += Double(value) * (Double(i) + 0.5) * Double(mult)
                        gSum += Double(value) * (Double(j) + 0.5) * Double(mult)
                        bSum += Double(value) * (Double(k) + 0.5) * Double(mult)
                    }
                }
            }

            if ntot == 0 {
                return RGB(
                    r: UInt8(min(255, mult * (r1 + r2 + 1) / 2)),
                    g: UInt8(min(255, mult * (g1 + g2 + 1) / 2)),
                    b: UInt8(min(255, mult * (b1 + b2 + 1) / 2))
                )
            }

            let r = min(255, Int(rSum / Double(ntot)))
            let g = min(255, Int(gSum / Double(ntot)))
            let b = min(255, Int(bSum / Double(ntot)))
            return RGB(r: UInt8(r), g: UInt8(g), b: UInt8(b))
        }
    }

    struct PQueue<Element> {
        private var contents: [Element] = []
        private var sorted = true
        private let compare: (Element, Element) -> Bool

        init(compare: @escaping (Element, Element) -> Bool) {
            self.compare = compare
        }

        var size: Int { contents.count }
        var isEmpty: Bool { contents.isEmpty }

        mutating func push(_ element: Element) {
            contents.append(element)
            sorted = false
        }

        mutating func pop() -> Element? {
            ensureSorted()
            return contents.popLast()
        }

        mutating func ensureSorted() {
            guard !sorted else { return }
            contents.sort(by: compare)
            sorted = true
        }
    }
}
