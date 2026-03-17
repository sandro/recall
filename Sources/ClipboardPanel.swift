import AppKit
import Combine

class ClickableTableView: NSTableView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

class ClickableScrollView: NSScrollView {
    var onScroll: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        onScroll?()
    }
}

class HoverableClipboardCell: NSTableCellView {
    var deleteButton: NSButton?
    var shortcutLabel: NSTextField?
    var pinButton: NSButton?
    private var trackingArea: NSTrackingArea?
    private var backgroundView: NSView?

    var backgroundColor: NSColor? {
        get {
            return backgroundView?.layer?.backgroundColor.flatMap { NSColor(cgColor: $0) }
        }
        set {
            if backgroundView == nil {
                let bgView = NSView(frame: bounds)
                bgView.wantsLayer = true
                bgView.autoresizingMask = [.width, .height]
                addSubview(bgView, positioned: .below, relativeTo: nil)
                backgroundView = bgView
            }
            backgroundView?.layer?.backgroundColor = newValue?.cgColor
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow, .assumeInside]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        // Only show buttons if the mouse is actually inside the visible bounds
        guard let window = window else { return }
        let mouseLocation = window.mouseLocationOutsideOfEventStream
        let localPoint = convert(mouseLocation, from: nil)

        if bounds.contains(localPoint) {
            deleteButton?.isHidden = false
            pinButton?.isHidden = false
        }
    }

    override func mouseExited(with event: NSEvent) {
        deleteButton?.isHidden = true
        pinButton?.isHidden = true
    }

    func clearHoverState() {
        deleteButton?.isHidden = true
        pinButton?.isHidden = true
    }
}

class PanelSearchField: NSSearchField {
    var onArrowDown: (() -> Void)?
    var onArrowUp: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 125, stringValue.isEmpty {
            onArrowDown?()
            return
        }
        if event.keyCode == 126, stringValue.isEmpty {
            onArrowUp?()
            return
        }
        super.keyDown(with: event)
    }
}

class ClipboardPanel: NSPanel, NSTableViewDataSource, NSTableViewDelegate {
    private let store: ClipboardStore
    private let tableView = ClickableTableView()
    private let scrollView = ClickableScrollView()
    private var previousApp: NSRunningApplication?
    private let clearButton = NSButton()
    private let searchField = PanelSearchField()
    private let regexCheckbox = NSButton(checkboxWithTitle: "Regex", target: nil, action: nil)
    private var cancellable: AnyCancellable?
    private var selectedIndex: Int = -1
    private var isDarkMode: Bool = false
    private var filteredEntries: [ClipboardEntry] = []

    init(store: ClipboardStore) {
        self.store = store

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 350),
            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = .canJoinAllSpaces
        self.title = "Recall"
        self.isFloatingPanel = true

        updateDarkMode()

        setupUI()
        setupObservers()
    }

    private func updateDarkMode() {
        let appearance = NSApp.effectiveAppearance
        let appearanceName = appearance.bestMatch(from: [.darkAqua, .aqua])
        isDarkMode = appearanceName == .darkAqua
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            orderOut(nil)
            return
        }

        let currentRow = selectedIndex >= 0 ? selectedIndex : tableView.clickedRow
        let entryCount = filteredEntries.count

        switch event.keyCode {
        case 126:
            if entryCount > 0 {
                selectedIndex = currentRow > 0 ? currentRow - 1 : entryCount - 1
                tableView.scrollRowToVisible(selectedIndex)
                tableView.reloadData()
            }
        case 125:
            if entryCount > 0 {
                selectedIndex = selectedIndex < entryCount - 1 ? selectedIndex + 1 : 0
                tableView.scrollRowToVisible(selectedIndex)
                tableView.reloadData()
            }
        case 36:
            if selectedIndex >= 0 && selectedIndex < entryCount {
                let entry = filteredEntries[selectedIndex]
                if let originalIndex = store.entries.firstIndex(where: { $0.id == entry.id }) {
                    pasteByIndex(originalIndex)
                }
            }
        default:
            super.keyDown(with: event)
        }
    }

    override var canBecomeKey: Bool {
        return true
    }

    private func setupObservers() {
        cancellable = store.$entries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.isVisible else { return }
                self.updateFilteredEntries()
            }

        // Close panel when it loses focus
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: self
        )
    }

    @objc private func windowDidResignKey(_ notification: Notification) {
        orderOut(nil)
    }

    private func setupUI() {
        let containerView = NSView(frame: contentView!.bounds)
        containerView.autoresizingMask = [.width, .height]

        // Search field at top
        searchField.frame = NSRect(x: 10, y: contentView!.bounds.height - 35, width: contentView!.bounds.width - 90, height: 24)
        searchField.placeholderString = "Search clipboard..."
        searchField.target = self
        searchField.action = #selector(searchFieldChanged)
        searchField.autoresizingMask = [.width, .minYMargin]
        searchField.onArrowDown = { [weak self] in
            guard let self = self, !self.filteredEntries.isEmpty else { return }
            self.selectedIndex = 0
            self.tableView.scrollRowToVisible(self.selectedIndex)
            self.tableView.reloadData()
            self.makeFirstResponder(self)
        }
        searchField.onArrowUp = { [weak self] in
            guard let self = self, !self.filteredEntries.isEmpty else { return }
            self.selectedIndex = self.filteredEntries.count - 1
            self.tableView.scrollRowToVisible(self.selectedIndex)
            self.tableView.reloadData()
            self.makeFirstResponder(self)
        }
        containerView.addSubview(searchField)

        // Regex checkbox next to search field
        regexCheckbox.frame = NSRect(x: contentView!.bounds.width - 75, y: contentView!.bounds.height - 35, width: 65, height: 24)
        regexCheckbox.target = self
        regexCheckbox.action = #selector(searchFieldChanged)
        regexCheckbox.autoresizingMask = [.minXMargin, .minYMargin]
        containerView.addSubview(regexCheckbox)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("content"))
        column.title = "Content"
        column.width = 700
        tableView.addTableColumn(column)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(tableViewSingleClicked)
        tableView.doubleAction = #selector(tableViewDoubleClicked)
        tableView.headerView = nil
        tableView.allowsMultipleSelection = false
        tableView.rowHeight = 30
        tableView.refusesFirstResponder = false
        tableView.selectionHighlightStyle = .regular

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.frame = NSRect(x: 0, y: 40, width: contentView!.bounds.width, height: contentView!.bounds.height - 80)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.onScroll = { [weak self] in
            self?.clearAllHoverStates()
        }
        containerView.addSubview(scrollView)

        clearButton.frame = NSRect(x: contentView!.bounds.width - 90, y: 10, width: 80, height: 24)
        clearButton.title = "Clear All"
        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearAll)
        clearButton.autoresizingMask = [.minXMargin, .maxYMargin]
        containerView.addSubview(clearButton)

        contentView = containerView
    }

    @objc private func searchFieldChanged() {
        updateFilteredEntries()
    }

    private func clearAllHoverStates() {
        for row in 0..<tableView.numberOfRows {
            if let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? HoverableClipboardCell {
                cell.clearHoverState()
            }
        }
    }

    private func updateFilteredEntries() {
        let searchText = searchField.stringValue.trimmingCharacters(in: .whitespaces)

        if searchText.isEmpty {
            filteredEntries = store.entries
        } else if regexCheckbox.state == .on {
            // Regex search
            filteredEntries = store.entries.filter { entry in
                guard let regex = try? NSRegularExpression(pattern: searchText, options: []) else {
                    // Invalid regex - fall back to contains
                    return entry.content.lowercased().contains(searchText.lowercased())
                }
                let range = NSRange(entry.content.startIndex..., in: entry.content)
                return regex.firstMatch(in: entry.content, options: [], range: range) != nil
            }
        } else {
            // Simple case-insensitive contains search
            filteredEntries = store.entries.filter { entry in
                entry.content.lowercased().contains(searchText.lowercased())
            }
        }

        selectedIndex = -1
        tableView.reloadData()
    }

    func show() {
        selectedIndex = -1
        searchField.stringValue = ""
        regexCheckbox.state = .off
        updateFilteredEntries()

        let allApps = NSWorkspace.shared.runningApplications

        if let frontmost = allApps.first(where: {
            $0.isActive && $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }) {
            previousApp = frontmost
        } else {
            previousApp = NSWorkspace.shared.frontmostApplication
        }

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelFrame = frame
            let x = screenFrame.midX - panelFrame.width / 2
            let y = screenFrame.midY - panelFrame.height / 2
            setFrameOrigin(NSPoint(x: x, y: y))
        }

        makeKeyAndOrderFront(nil)
        makeFirstResponder(searchField)
    }

    @objc private func clearAll() {
        store.clear()
        selectedIndex = -1
        updateFilteredEntries()
    }

    @objc private func deleteEntry(_ sender: NSButton) {
        let row = tableView.row(for: sender)
        guard row >= 0, row < filteredEntries.count else { return }

        let entry = filteredEntries[row]
        if let originalIndex = store.entries.firstIndex(where: { $0.id == entry.id }) {
            store.remove(at: originalIndex)
        }
        selectedIndex = -1
    }

    @objc private func pinEntry(_ sender: NSButton) {
        let row = tableView.row(for: sender)
        guard row >= 0, row < filteredEntries.count else { return }

        let entry = filteredEntries[row]
        if let originalIndex = store.entries.firstIndex(where: { $0.id == entry.id }) {
            store.togglePin(at: originalIndex)
        }
        selectedIndex = -1
    }

    @objc private func tableViewSingleClicked() {
        selectedIndex = tableView.clickedRow
        tableView.reloadData()
    }

    @objc private func tableViewDoubleClicked() {
        let row = tableView.clickedRow
        guard row >= 0, row < filteredEntries.count else { return }

        selectedIndex = -1
        let entry = filteredEntries[row]
        if let originalIndex = store.entries.firstIndex(where: { $0.id == entry.id }) {
            pasteByIndex(originalIndex)
        }
    }

    func pasteByIndex(_ index: Int) {
        guard index >= 0, index < store.entries.count else { return }

        let entry = store.entries[index]
        let content = entry.content

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)

        // Hide panel first
        orderOut(nil)

        // Activate previous app and simulate paste
        if let app = previousApp {
            app.activate(options: [.activateIgnoringOtherApps])

            // Wait briefly for app to become active
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.simulatePaste()
            }
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let source = source else { return }

        guard let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
              let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false),
              let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) else {
            return
        }

        vDown.flags = .maskCommand
        vUp.flags = .maskCommand

        cmdDown.post(tap: .cghidEventTap)
        usleep(1000)
        vDown.post(tap: .cghidEventTap)
        usleep(1000)
        vUp.post(tap: .cghidEventTap)
        usleep(1000)
        cmdUp.post(tap: .cghidEventTap)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredEntries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("ClipboardCell")

        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? HoverableClipboardCell

        if cell == nil {
            cell = HoverableClipboardCell()
            cell?.identifier = identifier

            let shortcutLabel = NSTextField()
            shortcutLabel.isBordered = false
            shortcutLabel.backgroundColor = .clear
            shortcutLabel.isEditable = false
            shortcutLabel.font = NSFont.systemFont(ofSize: 11)
            shortcutLabel.textColor = .secondaryLabelColor
            shortcutLabel.alignment = .left
            shortcutLabel.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(shortcutLabel)
            cell?.shortcutLabel = shortcutLabel

            let pinButton = NSButton()
            pinButton.title = "★"
            pinButton.bezelStyle = .rounded
            pinButton.font = NSFont.systemFont(ofSize: 14)
            pinButton.target = self
            pinButton.action = #selector(pinEntry(_:))
            pinButton.translatesAutoresizingMaskIntoConstraints = false
            pinButton.setContentHuggingPriority(.required, for: .horizontal)
            pinButton.isHidden = true
            cell?.addSubview(pinButton)
            cell?.pinButton = pinButton

            let textField = NSTextField()
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = false
            textField.lineBreakMode = .byTruncatingTail
            textField.usesSingleLineMode = true
            textField.cell?.lineBreakMode = .byTruncatingTail
            textField.cell?.truncatesLastVisibleLine = true
            textField.alignment = .left
            textField.maximumNumberOfLines = 1
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(textField)
            cell?.textField = textField

            let deleteButton = NSButton()
            deleteButton.title = "×"
            deleteButton.bezelStyle = .rounded
            deleteButton.font = NSFont.systemFont(ofSize: 18)
            deleteButton.target = self
            deleteButton.action = #selector(deleteEntry(_:))
            deleteButton.translatesAutoresizingMaskIntoConstraints = false
            deleteButton.setContentHuggingPriority(.required, for: .horizontal)
            deleteButton.isHidden = true
            cell?.addSubview(deleteButton)
            cell?.deleteButton = deleteButton

            NSLayoutConstraint.activate([
                shortcutLabel.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 5),
                shortcutLabel.widthAnchor.constraint(equalToConstant: 30),
                shortcutLabel.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),

                pinButton.leadingAnchor.constraint(equalTo: shortcutLabel.trailingAnchor, constant: 5),
                pinButton.widthAnchor.constraint(equalToConstant: 24),
                pinButton.heightAnchor.constraint(equalToConstant: 24),
                pinButton.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),

                textField.leadingAnchor.constraint(equalTo: pinButton.trailingAnchor, constant: 5),
                textField.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -5),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),

                deleteButton.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -5),
                deleteButton.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                deleteButton.widthAnchor.constraint(equalToConstant: 24),
                deleteButton.heightAnchor.constraint(equalToConstant: 24)
            ])
        }

        guard row >= 0, row < filteredEntries.count else { return cell }
        let entry = filteredEntries[row]

        cell?.deleteButton?.isHidden = true
        cell?.pinButton?.isHidden = true

        if row < 9 {
            cell?.shortcutLabel?.stringValue = "⌘\(row + 1)"
        } else if row == 9 {
            cell?.shortcutLabel?.stringValue = "⌘0"
        } else {
            cell?.shortcutLabel?.stringValue = ""
        }

        if entry.isPinned {
            cell?.pinButton?.title = "★"
            cell?.pinButton?.isHidden = false
        }

        let displayContent = entry.content
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        cell?.textField?.stringValue = displayContent

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        let timestampString = formatter.string(from: entry.timestamp)

        cell?.toolTip = "Copied: \(timestampString)\n\n\(entry.content)"

        if row == selectedIndex {
            cell?.backgroundColor = NSColor.selectedContentBackgroundColor
            cell?.textField?.textColor = NSColor.white
            cell?.shortcutLabel?.textColor = NSColor.white
        } else {
            cell?.backgroundColor = NSColor.clear
            cell?.textField?.textColor = NSColor.labelColor
            cell?.shortcutLabel?.textColor = NSColor.secondaryLabelColor
        }

        return cell
    }
}
