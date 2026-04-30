import Foundation

enum KMeansEngine {
    static let maxIterations = 32
    static let convergenceThreshold = 1.0  // mean centroid drift in 8-bit RGB units

    static func quantize(
        pixels: [PixelTriplet],
        maxColors: Int,
        seed: UInt64 = 0xC0FFEE
    ) -> [QuantizedColor] {
        guard !pixels.isEmpty, maxColors >= 2, maxColors <= 256 else { return [] }
        let k = min(maxColors, pixels.count)

        var centroids = kMeansPlusPlusInit(pixels: pixels, k: k, seed: seed)
        var assignments = [Int](repeating: 0, count: pixels.count)

        for _ in 0..<maxIterations {
            for (i, p) in pixels.enumerated() {
                assignments[i] = nearestCentroid(p, centroids)
            }
            let (newCentroids, drift) = recomputeCentroids(
                pixels: pixels,
                assignments: assignments,
                k: k,
                fallback: centroids
            )
            centroids = newCentroids
            if drift < convergenceThreshold { break }
        }

        var populations = [Int](repeating: 0, count: k)
        for a in assignments { populations[a] += 1 }
        return zip(centroids, populations)
            .filter { $0.1 > 0 }
            .map { centroid, pop in
                QuantizedColor(color: centroid, population: pop)
            }
    }

    static func kMeansPlusPlusInit(
        pixels: [PixelTriplet],
        k: Int,
        seed: UInt64
    ) -> [PixelTriplet] {
        var rng = SeedablePRNG(seed: seed)
        var centroids: [PixelTriplet] = []
        let firstIdx = Int(rng.next() % UInt64(pixels.count))
        centroids.append(pixels[firstIdx])
        while centroids.count < k {
            var distances = [Double](repeating: 0, count: pixels.count)
            var totalDistance = 0.0
            for (i, p) in pixels.enumerated() {
                let d = nearestCentroidDistanceSquared(p, centroids)
                distances[i] = d
                totalDistance += d
            }
            guard totalDistance > 0 else { break }
            let target = (Double(rng.next() % UInt64.max) / Double(UInt64.max)) * totalDistance
            var cumulative = 0.0
            for (i, d) in distances.enumerated() {
                cumulative += d
                if cumulative >= target {
                    centroids.append(pixels[i])
                    break
                }
            }
        }
        return centroids
    }

    @inline(__always)
    private static func nearestCentroid(
        _ p: PixelTriplet,
        _ centroids: [PixelTriplet]
    ) -> Int {
        var best = Double.infinity
        var bestIdx = 0
        for (i, c) in centroids.enumerated() {
            let dr = Double(p.r) - Double(c.r)
            let dg = Double(p.g) - Double(c.g)
            let db = Double(p.b) - Double(c.b)
            let d = dr*dr + dg*dg + db*db
            if d < best { best = d; bestIdx = i }
        }
        return bestIdx
    }

    @inline(__always)
    private static func nearestCentroidDistanceSquared(
        _ p: PixelTriplet,
        _ centroids: [PixelTriplet]
    ) -> Double {
        var best = Double.infinity
        for c in centroids {
            let dr = Double(p.r) - Double(c.r)
            let dg = Double(p.g) - Double(c.g)
            let db = Double(p.b) - Double(c.b)
            let d = dr*dr + dg*dg + db*db
            if d < best { best = d }
        }
        return best
    }

    private static func recomputeCentroids(
        pixels: [PixelTriplet],
        assignments: [Int],
        k: Int,
        fallback: [PixelTriplet]
    ) -> ([PixelTriplet], Double) {
        var sumR = [Double](repeating: 0, count: k)
        var sumG = [Double](repeating: 0, count: k)
        var sumB = [Double](repeating: 0, count: k)
        var counts = [Int](repeating: 0, count: k)
        for (i, p) in pixels.enumerated() {
            let a = assignments[i]
            sumR[a] += Double(p.r); sumG[a] += Double(p.g); sumB[a] += Double(p.b)
            counts[a] += 1
        }
        var newCentroids: [PixelTriplet] = []
        newCentroids.reserveCapacity(k)
        var totalDrift = 0.0
        for i in 0..<k {
            if counts[i] == 0 {
                newCentroids.append(fallback[i])
                continue
            }
            let r = UInt8(min(255, Int(sumR[i] / Double(counts[i]))))
            let g = UInt8(min(255, Int(sumG[i] / Double(counts[i]))))
            let b = UInt8(min(255, Int(sumB[i] / Double(counts[i]))))
            let nc = PixelTriplet(r: r, g: g, b: b)
            let dr = Double(nc.r) - Double(fallback[i].r)
            let dg = Double(nc.g) - Double(fallback[i].g)
            let db = Double(nc.b) - Double(fallback[i].b)
            totalDrift += (dr*dr + dg*dg + db*db).squareRoot()
            newCentroids.append(nc)
        }
        return (newCentroids, totalDrift / Double(k))
    }
}

/// Linear-congruential seedable PRNG used for reproducible k-means++
/// centroid initialization. Not cryptographic; the only requirement is
/// determinism for a given seed.
struct SeedablePRNG {
    private var state: UInt64
    init(seed: UInt64) {
        self.state = seed == 0 ? 0xC0FFEE : seed
    }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
