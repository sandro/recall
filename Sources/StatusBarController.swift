import AppKit

class StatusBarController {
    var statusItem: NSStatusItem?
    private let panel: ClipboardPanel
    private var menu: NSMenu?

    init(panel: ClipboardPanel) {
        self.panel = panel
    }

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            if let resourcePath = Bundle.main.resourcePath,
               let image = NSImage(contentsOfFile: resourcePath + "/StatusBarIcon.png") {
                button.image = image
            }
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        setupMenu()
    }

    private func setupMenu() {
        let contextMenu = NSMenu()

        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitMenuItem.target = self
        contextMenu.addItem(quitMenuItem)

        menu = contextMenu
    }

    @objc private func statusBarButtonClicked(sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!

        if event.type == .rightMouseUp {
            menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
        } else {
            panel.show()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    func removeStatusBar() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }
}
