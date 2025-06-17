import Foundation
import FirebaseFirestoreSwift

struct Comment: Identifiable, Codable {
    @DocumentID var id: String?
    var text: String
    var userUID: String
    var username: String
    var userProfileURL: URL?
    var timestamp: Date
    var likedBy: [String]?
}
