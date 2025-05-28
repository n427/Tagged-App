import SwiftUI

enum Tab: String {
    case home
    case messages
    case create
    case crown
    case profile
}

struct MainView: View {
    @AppStorage("selected_tab") private var selectedTab: Tab = .home

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()

            Divider()
                .frame(height: 0.5)
                .background(Color.gray.opacity(0.3))

            TabView(selection: $selectedTab) { // 👈 Track selected tab

                VStack {
                    Spacer().frame(height: 16)
                    Text("Home View")
                    Spacer()
                }
                .tabItem {
                    Image(systemName: "house")
                }
                .tag(Tab.home) // 👈 Tag for identification

                VStack {
                    Spacer().frame(height: 16)
                    Text("Messages View")
                    Spacer()
                }
                .tabItem {
                    Image(systemName: "envelope")
                }
                .tag(Tab.messages)

                VStack {
                    CreateNewPost { _ in }
                        .padding(.top, 12)
                }
                .tabItem {
                    Image(systemName: "camera")
                }
                .tag(Tab.create)

                VStack {
                    Spacer().frame(height: 16)
                    Text("Crown View")
                    Spacer()
                }
                .tabItem {
                    Image(systemName: "crown")
                }
                .tag(Tab.crown)

                VStack {
                    ProfileView()
                        .padding(.top, 12)
                }
                .tabItem {
                    Image(systemName: "person")
                }
                .tag(Tab.profile)
            }
            .tint(Color("AccentColor"))
        }
    }
}
