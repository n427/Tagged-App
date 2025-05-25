//
//  User.swift
//  Tagged
//
//  Created by Nicole Zhang on 2025-05-24.
//

import SwiftUI
import FirebaseFirestoreSwift

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var username: String
    var name: String
    var userBio: String
    var userUID: String
    var userEmail: String
    var userProfileURL: URL
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case username
        case userBio
        case userUID
        case userEmail
        case userProfileURL
    }
}

