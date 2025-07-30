import SwiftUI
import FirebaseFirestore

struct Post: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var title: String
    var text: String
    var imageURL: URL?
    var imageReferenceID: String = ""
    var publishedDate: Date = Date()
    var likedIDs: [String] = []
    
    var userName: String
    var userUID: String
    var userProfileURL: URL
    
    var groupID: String?
    var tag: String = ""
    
    enum CodingKeys: CodingKey {
        case id
        case title
        case text
        case imageURL
        case imageReferenceID
        case publishedDate
        case likedIDs
        case userName
        case userUID
        case userProfileURL
        case groupID
        case tag
    }
}
