import AppKit
import XCTest
@testable import MacAnyDoor

@MainActor
final class PortalControlHitTestingTests: XCTestCase {
    func testNotchPanelDoesNotConsumeClicksToActivateTheApp() {
        let panel = NotchPanel(contentRect: .zero)

        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(panel.becomesKeyOnlyIfNeeded)
        XCTAssertTrue(panel.canBecomeKey)
    }

    func testNativeHeaderHotspotsReceiveFirstClickAndRouteEveryAction() throws {
        var performedActions: [String] = []
        let container = TrackingContainerView(frame: NSRect(x: 0, y: 0, width: 720, height: 432))
        container.installActionHotspots(
            createMaterial: { performedActions.append("create-material") },
            renameMaterialArea: { performedActions.append("rename-material") },
            createCustomMaterial: { performedActions.append("create-custom") },
            renameCustomArea: { performedActions.append("rename-custom") }
        )
        let panel = NotchPanel(contentRect: container.frame)
        panel.contentView = container
        panel.makeKeyAndOrderFront(nil)
        defer { panel.close() }
        container.layoutSubtreeIfNeeded()

        let hotspotCenters = [
            NSPoint(x: 288.5, y: 282.5),
            NSPoint(x: 345, y: 282),
            NSPoint(x: 635.5, y: 282.5),
            NSPoint(x: 692, y: 282)
        ]

        for point in hotspotCenters {
            let button = try XCTUnwrap(container.hitTest(point) as? NSButton)
            XCTAssertTrue(button.acceptsFirstMouse(for: nil))
            button.performClick(nil)
        }

        XCTAssertEqual(
            performedActions,
            ["create-material", "rename-material", "create-custom", "rename-custom"]
        )
    }

    func testDragHoverOverPermanentTabUsesWindowCoordinates() {
        let (panel, container) = makeDragContainer()
        defer { panel.close() }
        container.activeSection = .temporary

        XCTAssertEqual(
            container.destination(atWindowPoint: NSPoint(x: 520, y: 335)),
            .permanentTab
        )
    }

    func testCustomAreaAcceptsTheSameWindowCoordinateDragHitAsMaterialArea() {
        let (panel, container) = makeDragContainer()
        defer { panel.close() }
        container.activeSection = .permanent

        XCTAssertEqual(
            container.destination(atWindowPoint: NSPoint(x: 190, y: 140)),
            .permanentArea
        )
        XCTAssertEqual(
            container.destination(atWindowPoint: NSPoint(x: 540, y: 140)),
            .customArea
        )
    }

    private func makeDragContainer() -> (NotchPanel, TrackingContainerView) {
        let container = TrackingContainerView(frame: NSRect(x: 0, y: 0, width: 720, height: 432))
        let panel = NotchPanel(contentRect: container.frame)
        panel.setFrameOrigin(NSPoint(x: 900, y: 500))
        panel.contentView = container

        // A non-zero screen origin is intentional:
        // treating draggingLocation as a screen point would make these hits
        // miss the panel entirely.
        XCTAssertNotNil(container.window)
        return (panel, container)
    }

}
