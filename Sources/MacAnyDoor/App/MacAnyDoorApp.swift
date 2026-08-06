import AppKit

@main
struct MacAnyDoorApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = PortalStore()
    private lazy var panelController = NotchPanelController(store: store)
    private lazy var settingsWindowController = SettingsWindowController(store: store)
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController.install()
        installStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.purgeExpired(showNotice: false)
    }

    @objc
    private func openPortal() {
        panelController.show()
    }

    @objc
    private func saveClipboard() {
        store.importClipboard()
        panelController.show()
    }

    @objc
    private func clearTemporary() {
        store.clearTemporary()
    }

    @objc
    private func openSettings() {
        settingsWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func createPrompt() {
        store.showInformation("Prompt 创建将在阶段二提供；当前可先保存一次性和长期素材。")
        panelController.show()
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }

    private func installStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "door.left.hand.open", accessibilityDescription: "Mac 任意门")
        statusItem.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        menu.addItem(withTitle: "打开任意门", action: #selector(openPortal), keyEquivalent: "")
        menu.addItem(withTitle: "新建 Prompt（下一阶段）", action: #selector(createPrompt), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "保存当前剪贴板", action: #selector(saveClipboard), keyEquivalent: "v")
        menu.addItem(withTitle: "清空一次性区域", action: #selector(clearTemporary), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 Mac 任意门", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }

        statusItem.menu = menu
        self.statusItem = statusItem
    }
}
