import Foundation

struct ClipboardEntry: Identifiable, Equatable, Comparable {
    let id: UUID
    let content: String
    var timestamp: Date
    var isPinned: Bool = false

    init(content: String) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.isPinned = false
    }

    static func == (lhs: ClipboardEntry, rhs: ClipboardEntry) -> Bool {
        return lhs.content == rhs.content
    }
    
    static func < (lhs: ClipboardEntry, rhs: ClipboardEntry) -> Bool {
        // Pinned items come first, then by timestamp (newest first)
        if lhs.isPinned != rhs.isPinned {
            return lhs.isPinned
        }
        return lhs.timestamp > rhs.timestamp
    }
}
