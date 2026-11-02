import PaletteKit
import SwiftUI
import UIKit
import XCTest
@testable import PaletteKitDemo

@MainActor
final class GraphicColorCountPickerTests: XCTestCase {
    func testHostedLabUpdatesSegmentsAndSelectionWhenInputsChange() throws {
        let host = UIHostingController(rootView: lab([.white, gray(200), gray(140), gray(70), .black]))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        defer { window.isHidden = true }

        waitUntil { Self.colorPicker(in: host.view) != nil }
        let control = try XCTUnwrap(Self.colorPicker(in: host.view))
        XCTAssertEqual(control.accessibilityLabel, "Colors")
        assertSegments(control, enabled: [0, 1, 2, 3], selected: 0)

        control.selectedSegmentIndex = 3
        control.sendActions(for: .valueChanged)
        host.rootView = lab([.white, gray(140), .black])
        waitUntil { control.selectedSegmentIndex == 1 && !control.isEnabledForSegment(at: 2) }
        assertSegments(control, enabled: [0, 1], selected: 1)

        host.rootView = lab([.white, gray(200), gray(140), gray(70), .black])
        waitUntil { control.isEnabledForSegment(at: 3) }
        assertSegments(control, enabled: [0, 1, 2, 3], selected: 1)

        host.rootView = lab([.black])
        waitUntil { control.selectedSegmentIndex == UISegmentedControl.noSegment }
        assertSegments(control, enabled: [], selected: UISegmentedControl.noSegment)
        XCTAssertEqual(control.accessibilityHint, "The current combination produces a single color.")

        host.rootView = lab([.white, .black])
        waitUntil { control.isEnabledForSegment(at: 0) }
        assertSegments(control, enabled: [0], selected: 0)
    }

    func testHostedLabCorrectsSelectionOnStrategyChange() throws {
        // The darkest color is dominant: Vibrant and Muted collapse to one
        // color, while Contrast uses the lightest and darkest palette colors.
        let host = UIHostingController(rootView: lab([.black, gray(140), .white]))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        defer { window.isHidden = true }

        waitUntil { Self.colorPicker(in: host.view) != nil }
        let control = try XCTUnwrap(Self.colorPicker(in: host.view))
        let strategy = try XCTUnwrap(Self.segments(in: host.view).first { $0.titleForSegment(at: 0) == "Vibrant" })
        assertSegments(control, enabled: [], selected: UISegmentedControl.noSegment)

        strategy.selectedSegmentIndex = 1
        strategy.sendActions(for: .valueChanged)
        waitUntil { control.isEnabledForSegment(at: 1) }
        assertSegments(control, enabled: [0, 1], selected: 0)
        control.selectedSegmentIndex = 1
        control.sendActions(for: .valueChanged)

        strategy.selectedSegmentIndex = 2
        strategy.sendActions(for: .valueChanged)
        waitUntil { control.selectedSegmentIndex == UISegmentedControl.noSegment }
        assertSegments(control, enabled: [], selected: UISegmentedControl.noSegment)

        strategy.selectedSegmentIndex = 1
        strategy.sendActions(for: .valueChanged)
        waitUntil { control.selectedSegmentIndex == 0 }
        assertSegments(control, enabled: [0, 1], selected: 0)
    }

    private func assertSegments(_ control: UISegmentedControl, enabled: Set<Int>, selected: Int,
                                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(control.numberOfSegments, 4, file: file, line: line)
        XCTAssertEqual(control.selectedSegmentIndex, selected, file: file, line: line)
        for index in 0..<4 {
            XCTAssertEqual(control.isEnabledForSegment(at: index), enabled.contains(index), file: file, line: line)
        }
    }

    private func waitUntil(_ condition: @escaping @MainActor @Sendable () -> Bool,
                           file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { condition() }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed, file: file, line: line)
    }

    private static func colorPicker(in view: UIView) -> UISegmentedControl? {
        segments(in: view).first { $0.accessibilityIdentifier == "graphic.colors" }
    }

    private static func segments(in view: UIView) -> [UISegmentedControl] {
        (view as? UISegmentedControl).map { [$0] } ?? view.subviews.flatMap { segments(in: $0) }
    }

    private func lab(_ colors: [PaletteColor]) -> CardLabView {
        CardLabView(palette: Palette(colors: colors, colorSpaceUsed: .oklch), swatches: nil)
    }

    private func gray(_ value: UInt8) -> PaletteColor { PaletteColor(r: value, g: value, b: value) }
}
