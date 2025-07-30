import SwiftUI
import FirebaseFirestore

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var username: String
    var name: String
    var userBio: String
    var userUID: String
    var userEmail: String
    var userProfileURL: URL?
    var userLikeCount: Int = 0
    var fcmToken: String? = nil

    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case username
        case userBio
        case userUID
        case userEmail
        case userProfileURL
        case userLikeCount
        case fcmToken
    }
}

