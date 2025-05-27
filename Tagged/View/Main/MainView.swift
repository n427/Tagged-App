//
//  MainView.swift
//  Tagged
//
//  Created by Nicole Zhang on 2025-05-26.
//

import SwiftUI

struct MainView: View {
    var body: some View {
        VStack() {
            HeaderView()
            TabView {
                VStack {
                        Spacer().frame(height: 16) // Top spacing
                        Text("Home View")
                        Spacer()
                    }
                    .tabItem {
                        Image(systemName: "house")
                    }

                    VStack {
                        Spacer().frame(height: 16)
                        Text("Messages View")
                        Spacer()
                    }
                    .tabItem {
                        Image(systemName: "envelope")
                    }

                    VStack {
                        Spacer().frame(height: 16)
                        Text("Camera View")
                        Spacer()
                    }
                    .tabItem {
                        Image(systemName: "camera")
                    }

                    VStack {
                        Spacer().frame(height: 16)
                        Text("Crown View")
                        Spacer()
                    }
                    .tabItem {
                        Image(systemName: "crown")
                    }

                    VStack {
                        ProfileView()
                            .padding(.top, 12)
                    }
                    .tabItem {
                        Image(systemName: "person")
                    }
            }
            .tint(Color("AccentColor"))
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
