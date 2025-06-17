import SwiftUI
import FirebaseFirestoreSwift
import FirebaseFirestore

struct Group: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var detailedDescription: String?
    var roomCode: String
    var isPlayMode: Bool
    var hasPunishment: Bool
    var captions: [String]
    var imageURL: URL?
    var createdBy: String
    var createdAt: Timestamp?
}
