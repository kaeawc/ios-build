import Foundation
import SQLiteData

@Table("session")
struct Session {
    var id: UUID
    var launchedAt: Date
}
