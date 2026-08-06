import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchPanelController: NSObject, ObservableObject {
    static let collapsedSize = NSSize(width: 180, height: 34)
    static let expandedSize = NSSize(width: 720, height: 540)

    @Published private(set) var isExpanded = false

    private let store: PortalStore
    private let dropImporter: DropImporter
    private var panel: NotchPanel?
    private var hostingView: TrackingHostingView<PortalRootView>?
    private var collapseWorkItem: DispatchWorkItem?

    init(store: PortalStore) {
        self.store = store
        self.dropImporter = DropImporter(store: store)
        super.init()
    }

    func install() {
        guard panel == nil else { return }

        let panel = NotchPanel(contentRect: .zero)

        let rootView = PortalRootView(
            store: store,
            panelController: self,
            dropImporter: dropImporter
        )
        let hostingView = TrackingHostingView(rootView: rootView)
        hostingView.panelController = self
        hostingView.registerForDraggedTypes(DropImporter.acceptedTypes.map { NSPasteboard.PasteboardType($0.identifier) })
        panel.contentView = hostingView

        self.panel = panel
        self.hostingView = hostingView
        updateFrame(animated: false)
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reposition),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func show() {
        setExpanded(true)
    }

    func toggle() {
        setExpanded(!isExpanded)
    }

    func collapse() {
        setExpanded(false)
    }

    func pointerEntered() {
        collapseWorkItem?.cancel()
        setExpanded(true)
    }

    func pointerExited() {
        guard isExpanded else { return }
        collapseWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.setExpanded(false)
        }
        collapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: workItem)
    }

    func draggingEnteredPanel() {
        collapseWorkItem?.cancel()
        setExpanded(true)
    }

    @objc
    private func reposition() {
        updateFrame(animated: false)
    }

    private func setExpanded(_ expanded: Bool) {
        collapseWorkItem?.cancel()
        guard isExpanded != expanded else {
            panel?.orderFrontRegardless()
            return
        }
        isExpanded = expanded
        updateFrame(animated: true, expanding: expanded)
        panel?.orderFrontRegardless()
    }

    private func updateFrame(animated: Bool, expanding: Bool = false) {
        guard let panel else { return }
        let size = isExpanded ? Self.expandedSize : Self.collapsedSize
        hostingView?.frame = NSRect(origin: .zero, size: size)
        let frame = frame(for: size, on: panel.screen)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                // The expansion starts quickly and settles gently, which reads
                // closer to a Dynamic Island growing out of the notch than a
                // generic window resize.
                context.duration = expanding ? 0.46 : 0.3
                context.timingFunction = expanding
                    ? CAMediaTimingFunction(controlPoints: 0.22, 0.94, 0.36, 1.0)
                    : CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private func frame(for size: NSSize, on screen: NSScreen?) -> NSRect {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen else {
            return NSRect(origin: .zero, size: size)
        }

        // This anchors to the physical top centre. On notched displays it
        // visually occupies the notch region; on other displays it is the
        // documented top-centre fallback.
        return NSRect(
            x: targetScreen.frame.midX - size.width / 2,
            y: targetScreen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}

private final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class TrackingHostingView<Content: View>: NSHostingView<Content> {
    weak var panelController: NotchPanelController?
    private var hoverTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        panelController?.pointerEntered()
    }

    override func mouseExited(with event: NSEvent) {
        panelController?.pointerExited()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        panelController?.draggingEnteredPanel()
        return .copy
    }
}
