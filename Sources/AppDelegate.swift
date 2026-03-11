import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var clipboardStore: ClipboardStore!
    private var clipboardMonitor: ClipboardMonitor!
    private var hotkeyManager: HotkeyManager!
    private var statusBarController: StatusBarController!
    private var clipboardPanel: ClipboardPanel!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize components
        clipboardStore = ClipboardStore()
        clipboardPanel = ClipboardPanel(store: clipboardStore)
        clipboardMonitor = ClipboardMonitor(store: clipboardStore)
        hotkeyManager = HotkeyManager()
        statusBarController = StatusBarController(panel: clipboardPanel)

        // Setup status bar
        statusBarController.setupStatusBar()

        // Start clipboard monitoring
        clipboardMonitor.startMonitoring()

        // Register global hotkeys
        hotkeyManager.onShowPanel = { [weak self] in
            self?.clipboardPanel.show()
        }
        hotkeyManager.onPasteByIndex = { [weak self] index in
            self?.clipboardPanel.pasteByIndex(index)
        }
        hotkeyManager.registerHotkeys()

        // Check for accessibility permissions
        checkAccessibilityPermissions()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        clipboardMonitor.stopMonitoring()
        hotkeyManager.unregisterHotkeys()
        statusBarController.removeStatusBar()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    private func checkAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessEnabled {
            NSLog("⚠️ Accessibility permissions required for global hotkey support")

            // Show alert
            let alert = NSAlert()
            alert.messageText = "Accessibility Access Required"
            alert.informativeText = "Recall needs Accessibility permissions to register the global hotkey (Ctrl+Shift+V). Please grant access in System Preferences."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } else {
            NSLog("✅ Accessibility permissions granted")
        }
    }
}
