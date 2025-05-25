//
//  ContentView.swift
//  Tagged
//
//  Created by Nicole Zhang on 2025-05-23.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("log_status") var logStatus: Bool = false
    var body: some View {
        if logStatus{
            Text("Main View")
        }
        else {
            WelcomeView()
        }
    }
}

#Preview {
    ContentView()
}
