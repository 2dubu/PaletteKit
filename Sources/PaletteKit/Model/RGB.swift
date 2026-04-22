import Foundation

public struct RGB: Hashable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }
}

public struct HSL: Hashable, Sendable {
    public var h: Int
    public var s: Int
    public var l: Int

    public init(h: Int, s: Int, l: Int) {
        self.h = h
        self.s = s
        self.l = l
    }
}

public struct OKLCH: Hashable, Sendable {
    public var l: Double
    public var c: Double
    public var h: Double

    public init(l: Double, c: Double, h: Double) {
        self.l = l
        self.c = c
        self.h = h
    }
}
