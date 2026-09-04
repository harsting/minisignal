import Foundation

/// Die letzten Nachrichten, nur lokal auf diesem Mac.
enum History {

    struct Entry: Codable {
        let text: String
        let who: String
        let incoming: Bool
        let at: Date
    }

    static let limit = 20
    private static let key = "history"

    static func add(text: String, who: String, incoming: Bool) {
        var entries = all()
        entries.insert(Entry(text: text, who: who, incoming: incoming, at: Date()), at: 0)
        if entries.count > limit { entries.removeLast(entries.count - limit) }
        if let data = try? JSONEncoder().encode(entries) {
            Settings.shared.store(data, forKey: key)
        }
    }

    static func all() -> [Entry] {
        guard let data = Settings.shared.data(forKey: key),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries
    }

    static func clear() {
        Settings.shared.store(nil, forKey: key)
    }
}
