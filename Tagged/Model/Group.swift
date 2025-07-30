import Foundation
import FirebaseFirestore

struct Group: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var detailedDescription: String?
    var roomCode: String
    var isPlayMode: Bool
    var hasPunishment: Bool
    var imageURL: URL?
    var createdBy: String
    var createdAt: Timestamp?
    var members: [String]? = []
    var adminID: String

    var asDictionary: [String: Any] {
        (try? Firestore.Encoder().encode(self)) ?? [:]
    }
}
