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
    private lazy var clipboardImporter = ClipboardImporter(store: store)
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
        clipboardImporter.importCurrentContents()
        panelController.show()
    }

    @objc
    private func createMaterial() {
        panelController.presentNewMaterialEditor(source: "status-menu")
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
    private func createCustomAreaContent() {
        panelController.presentNewMaterialEditor(source: "status-menu", scope: .custom)
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }

    private func installStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = PortalMenuIcon.door()
        statusItem.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        menu.addItem(withTitle: "打开任意门", action: #selector(openPortal), keyEquivalent: "")
        menu.addItem(withTitle: "新建长期素材", action: #selector(createMaterial), keyEquivalent: "n")
        menu.addItem(withTitle: "新建自定义区域内容", action: #selector(createCustomAreaContent), keyEquivalent: "")
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
