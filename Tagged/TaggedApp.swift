//
//  TaggedApp.swift
//  Tagged
//
//  Created by Nicole Zhang on 2025-05-23.
//

import SwiftUI
import Firebase

@main
struct TaggedApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView() // your TabView lives here
            }
        }
    }
}
