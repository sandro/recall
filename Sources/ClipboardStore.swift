import Foundation
import Combine

class ClipboardStore: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []

    func add(_ content: String) {
        guard !content.isEmpty else { return }

        // Check if content already exists
        if let existingIndex = entries.firstIndex(where: { $0.content == content }) {
            // Move existing entry to top and update timestamp
            var existingEntry = entries.remove(at: existingIndex)
            existingEntry.timestamp = Date()
            entries.insert(existingEntry, at: 0)
        } else {
            // Add new entry at the top
            let newEntry = ClipboardEntry(content: content)
            entries.insert(newEntry, at: 0)
        }
        // Re-sort to maintain proper ordering (pinned first, then by timestamp)
        entries.sort()
    }

    func remove(at index: Int) {
        guard index >= 0 && index < entries.count else { return }
        entries.remove(at: index)
    }

    func togglePin(at index: Int) {
        guard index >= 0 && index < entries.count else { return }
        entries[index].isPinned.toggle()
        // Re-sort to maintain proper ordering
        entries.sort()
    }

    func clear() {
        entries.removeAll()
    }

    func getAll() -> [ClipboardEntry] {
        return entries
    }
}
