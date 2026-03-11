import Carbon
import AppKit

class HotkeyManager {
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    var onShowPanel: (() -> Void)?
    var onPasteByIndex: ((Int) -> Void)?

    // Key codes for numbers 0-9
    private let numberKeyCodes: [UInt32] = [29, 18, 19, 20, 21, 23, 22, 26, 28, 25] // 0-9

    func registerHotkeys() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData!).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)

            manager.handleHotkey(id: Int(hotKeyID.id))
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)

        // Register Cmd+Shift+V to show panel (ID 1)
        registerSingleHotkey(keyCode: 9, modifiers: UInt32(cmdKey | shiftKey), id: 1, description: "Cmd+Shift+V")

        // Register Cmd+1 through Cmd+9 (IDs 11-19)
        for i in 1...9 {
            registerSingleHotkey(keyCode: numberKeyCodes[i], modifiers: UInt32(cmdKey), id: UInt32(10 + i), description: "Cmd+\(i)")
        }

        // Register Cmd+0 for 10th item (ID 20)
        registerSingleHotkey(keyCode: numberKeyCodes[0], modifiers: UInt32(cmdKey), id: 20, description: "Cmd+0")
    }

    private func registerSingleHotkey(keyCode: UInt32, modifiers: UInt32, id: UInt32, description: String) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x48544B59), id: id)
        let result = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        if result == noErr, let ref = hotKeyRef {
            hotKeyRefs.append(ref)
        }
    }

    private func handleHotkey(id: Int) {
        if id == 1 {
            // Cmd+Shift+V - Show panel
            onShowPanel?()
        } else if id >= 11 && id <= 19 {
            // Cmd+1 through Cmd+9 - Paste index 0-8
            let index = id - 11
            onPasteByIndex?(index)
        } else if id == 20 {
            // Cmd+0 - Paste index 9 (10th item)
            onPasteByIndex?(9)
        }
    }

    func unregisterHotkeys() {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    deinit {
        unregisterHotkeys()
    }
}
