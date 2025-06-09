//
//  Post.swift
//  Tagged
//
//  Created by Nicole Zhang on 2025-05-27.
//

import SwiftUI
import FirebaseFirestoreSwift

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
    }
}
