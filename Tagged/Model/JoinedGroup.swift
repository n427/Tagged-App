import Foundation
import FirebaseFirestore

struct JoinedGroup: Identifiable, Codable, Equatable {
    @DocumentID var id: String?

    var groupMeta: Group
    var streak: Int
    var lastPostDate: Timestamp?
    var lastTagWeek: Timestamp?
    var lastOpened: Timestamp?

    var groupID: String? { groupMeta.id }
}
