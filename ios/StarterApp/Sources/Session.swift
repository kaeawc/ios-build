import Foundation
import SQLiteData

@Table
struct Session {
    var id: UUID
    var launchedAt: Date
}
