#if canImport(SwiftUI) && canImport(UIKit)
import Testing
@testable import PaletteKit

@Suite("SwatchMap.color/titleTextColor/bodyTextColor (for:fallback:)")
struct SwatchMapLookupTests {
    private static func makeSwatch(role: SwatchRole,
                                   r: UInt8, g: UInt8, b: UInt8) -> Swatch {
        let color = PaletteColor(r: r, g: g, b: b)
        return Swatch(
            color: color,
            role: role,
            titleTextColor: .white,
            bodyTextColor: .black
        )
    }

    private static func fullMap() -> SwatchMap {
        SwatchMap(
            vibrant:      makeSwatch(role: .vibrant,      r: 200, g: 80,  b: 40),
            muted:        makeSwatch(role: .muted,        r: 150, g: 110, b: 90),
            darkVibrant:  makeSwatch(role: .darkVibrant,  r: 70,  g: 50,  b: 35),
            darkMuted:    makeSwatch(role: .darkMuted,    r: 30,  g: 20,  b: 10),
            lightVibrant: makeSwatch(role: .lightVibrant, r: 240, g: 200, b: 180),
            lightMuted:   makeSwatch(role: .lightMuted,   r: 220, g: 210, b: 200)
        )
    }

    @Test("color(for:fallback:) returns the role's swatch color when present")
    func colorPresent() {
        let map = Self.fullMap()
        let result = map.color(for: .vibrant, fallback: .black)
        #expect(result.rgb == RGB(r: 200, g: 80, b: 40))
    }

    @Test("color(for:fallback:) returns fallback when role is absent")
    func colorAbsent() {
        let map = SwatchMap()
        let result = map.color(for: .vibrant, fallback: .white)
        #expect(result.rgb == RGB(r: 255, g: 255, b: 255))
    }

    @Test("color(for:fallback:) handles each of the six roles independently")
    func colorEachRole() {
        let map = Self.fullMap()
        let expected: [(SwatchRole, RGB)] = [
            (.vibrant,      RGB(r: 200, g: 80,  b: 40)),
            (.muted,        RGB(r: 150, g: 110, b: 90)),
            (.darkVibrant,  RGB(r: 70,  g: 50,  b: 35)),
            (.darkMuted,    RGB(r: 30,  g: 20,  b: 10)),
            (.lightVibrant, RGB(r: 240, g: 200, b: 180)),
            (.lightMuted,   RGB(r: 220, g: 210, b: 200))
        ]
        for (role, rgb) in expected {
            #expect(map.color(for: role, fallback: .black).rgb == rgb)
        }
    }

    @Test("titleTextColor(for:fallback:) returns the swatch's title color when present")
    func titleColorPresent() {
        let map = Self.fullMap()
        let result = map.titleTextColor(for: .vibrant, fallback: .black)
        #expect(result.rgb == RGB(r: 255, g: 255, b: 255))
    }

    @Test("titleTextColor(for:fallback:) returns fallback when role is absent")
    func titleColorAbsent() {
        let map = SwatchMap()
        let result = map.titleTextColor(for: .darkMuted, fallback: .black)
        #expect(result.rgb == RGB(r: 0, g: 0, b: 0))
    }

    @Test("bodyTextColor(for:fallback:) returns the swatch's body color when present")
    func bodyColorPresent() {
        let map = Self.fullMap()
        let result = map.bodyTextColor(for: .vibrant, fallback: .white)
        #expect(result.rgb == RGB(r: 0, g: 0, b: 0))
    }

    @Test("bodyTextColor(for:fallback:) returns fallback when role is absent")
    func bodyColorAbsent() {
        let map = SwatchMap()
        let result = map.bodyTextColor(for: .lightMuted, fallback: .white)
        #expect(result.rgb == RGB(r: 255, g: 255, b: 255))
    }
}

@Suite("Optional<SwatchMap> convenience overloads")
struct OptionalSwatchMapLookupTests {
    private static func makeSwatch(role: SwatchRole,
                                   r: UInt8, g: UInt8, b: UInt8) -> Swatch {
        let color = PaletteColor(r: r, g: g, b: b)
        return Swatch(
            color: color,
            role: role,
            titleTextColor: .white,
            bodyTextColor: .black
        )
    }

    private static func mapWithVibrantOnly() -> SwatchMap {
        SwatchMap(vibrant: makeSwatch(role: .vibrant, r: 200, g: 80, b: 40))
    }

    @Test("nil SwatchMap returns fallback for every property")
    func nilMap() {
        let map: SwatchMap? = nil
        #expect(map.color(for: .vibrant, fallback: .black).rgb == RGB(r: 0, g: 0, b: 0))
        #expect(map.titleTextColor(for: .vibrant, fallback: .black).rgb == RGB(r: 0, g: 0, b: 0))
        #expect(map.bodyTextColor(for: .vibrant, fallback: .white).rgb == RGB(r: 255, g: 255, b: 255))
    }

    @Test("non-nil SwatchMap with absent role returns fallback")
    func absentRole() {
        let map: SwatchMap? = Self.mapWithVibrantOnly()
        #expect(map.color(for: .muted, fallback: .black).rgb == RGB(r: 0, g: 0, b: 0))
        #expect(map.titleTextColor(for: .darkMuted, fallback: .black).rgb == RGB(r: 0, g: 0, b: 0))
        #expect(map.bodyTextColor(for: .lightVibrant, fallback: .white).rgb == RGB(r: 255, g: 255, b: 255))
    }

    @Test("non-nil SwatchMap with present role returns swatch property")
    func presentRole() {
        let map: SwatchMap? = Self.mapWithVibrantOnly()
        #expect(map.color(for: .vibrant, fallback: .black).rgb == RGB(r: 200, g: 80, b: 40))
        #expect(map.titleTextColor(for: .vibrant, fallback: .black).rgb == RGB(r: 255, g: 255, b: 255))
        #expect(map.bodyTextColor(for: .vibrant, fallback: .white).rgb == RGB(r: 0, g: 0, b: 0))
    }
}
#endif
