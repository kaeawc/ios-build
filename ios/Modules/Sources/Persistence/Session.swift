import Foundation
import GRDB

/// One launch of the app, recorded when the root view first appears.
public struct Session: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var launchedAt: Date

    public init(id: UUID = UUID(), launchedAt: Date) {
        self.id = id
        self.launchedAt = launchedAt
    }
}

// MARK: - Database

/// `FetchableRecord` and `PersistableRecord` are synthesized from `Codable`: the table is named
/// `session` and has one column per stored property.
extension Session: FetchableRecord, PersistableRecord {
    /// Typed columns for building queries, e.g. `Session.order(Session.Columns.launchedAt.desc)`.
    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let launchedAt = Column(CodingKeys.launchedAt)
    }
}

/// What the UI shows about past launches: the total and the most recent few.
public struct SessionHistory: Equatable, Sendable {
    public var total: Int
    public var recent: [Session]

    public init(total: Int = 0, recent: [Session] = []) {
        self.total = total
        self.recent = recent
    }
}
