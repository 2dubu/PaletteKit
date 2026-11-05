import Testing

@testable import PaletteKit

@Suite("PaletteColor value semantics")
struct PaletteColorValueTests {
    @Test("equality and hashing retain population and proportion")
    func metadataRemainsPartOfIdentity() {
        let original = PaletteColor(r: 232, g: 67, b: 147, population: 100, proportion: 0.5)
        let same = PaletteColor(rgb: original.rgb, population: 100, proportion: 0.5)
        let differentPopulation = PaletteColor(rgb: original.rgb, population: 50, proportion: 0.5)
        let differentProportion = PaletteColor(rgb: original.rgb, population: 100, proportion: 0.25)

        #expect(original == same)
        #expect(original != differentPopulation)
        #expect(original != differentProportion)
        #expect(Set([original, same, differentPopulation, differentProportion]).count == 3)

        let values = [original: "original", differentPopulation: "population", differentProportion: "proportion"]
        #expect(values[same] == "original")
        #expect(values[differentPopulation] == "population")
        #expect(values[differentProportion] == "proportion")
    }
}
