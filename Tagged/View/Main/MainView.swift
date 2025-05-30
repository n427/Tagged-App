import SwiftUI

enum Tab: String {
    case home, messages, create, crown, profile
}

struct MainView: View {
    @AppStorage("selected_tab") private var selectedTabRaw: String = Tab.home.rawValue
    
    var selectedTab: Tab {
        get { Tab(rawValue: selectedTabRaw) ?? .home }
        set { selectedTabRaw = newValue.rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()

            Divider()
                .frame(height: 0.5)
                .background(Color.gray.opacity(0.3))

            ZStack {
                switch selectedTab {
                case .home:
                    VStack {
                        Spacer().frame(height: 16)
                        Text("Home View")
                        Spacer()
                    }
                case .messages:
                    VStack {
                        Spacer().frame(height: 16)
                        Text("Messages View")
                        Spacer()
                    }
                case .create:
                    VStack {
                        CreateNewPost { _ in }
                            .padding(.top, 12)
                    }
                case .crown:
                    VStack {
                        Spacer().frame(height: 16)
                        Text("Crown View")
                        Spacer()
                    }
                case .profile:
                    VStack {
                        ProfileView()
                            .padding(.top, 12)
                    }
                }
            }

            Divider()
                .frame(height: 0.5)
                .background(Color.gray.opacity(0.3))

            CustomTabBar(selectedTab: Binding(
                get: { Tab(rawValue: selectedTabRaw) ?? .home },
                set: { selectedTabRaw = $0.rawValue }
            ))
        }
        .ignoresSafeArea(.keyboard)
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Tab

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.3))

            HStack {
                tabButton(tab: .home, icon: "house")
                tabButton(tab: .messages, icon: "envelope")
                tabButton(tab: .create, icon: "camera")
                tabButton(tab: .crown, icon: "crown")
                tabButton(tab: .profile, icon: "person")
            }
            .padding(.top, 15)
            .padding(.bottom, 15)
            .background(Color.white.ignoresSafeArea(edges: .bottom))
            .shadow(color: .black.opacity(0.05), radius: 5, y: -2) // 👈 subtle shadow
        }
    }

    private func tabButton(tab: Tab, icon: String) -> some View {
        Button(action: {
            selectedTab = tab
        }) {
            VStack(spacing: 4) {
                Image(systemName: selectedTab == tab ? "\(icon).fill" : icon)
                    .font(.system(size: 22))
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(selectedTab == tab ? Color("AccentColor") : .secondary)
        }
    }
}
