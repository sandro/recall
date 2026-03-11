import AppKit

class ClipboardMonitor {
    private let pasteboard = NSPasteboard.general
    private var changeCount: Int
    private var timer: Timer?
    private let store: ClipboardStore
    private let pollingInterval: TimeInterval = 0.3

    init(store: ClipboardStore) {
        self.store = store
        self.changeCount = pasteboard.changeCount
    }

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        let currentChangeCount = pasteboard.changeCount

        if currentChangeCount != changeCount {
            changeCount = currentChangeCount

            // Extract string content
            if let content = pasteboard.string(forType: .string) {
                store.add(content)
            }
        }
    }
}
