import SwiftUI

// MARK: - Tab Enum

enum Tab: String {
    case home, messages, create, crown, profile
}

// MARK: - Main View

struct MainView: View {
    // MARK: - AppStorage & State

    @AppStorage("selected_tab") private var selectedTabRaw: String = Tab.home.rawValue

    @State private var showMenu = false
    @State private var showCreatePage = false
    @State private var showJoinModal = false
    @State private var showGroupsPage = false
    @State private var showSearch = false
    @State private var showSettings = false

    @State private var activeGroupID: UUID = UUID()
    @State private var explorePosts: [Post] = []
    @State private var exploreViewID = UUID()

    // MARK: - Computed Tab Binding

    var selectedTab: Tab {
        get { Tab(rawValue: selectedTabRaw) ?? .home }
        set { selectedTabRaw = newValue.rawValue }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    HeaderView(showMenu: $showMenu, showSearch: $showSearch, showSettings: $showSettings)

                    Divider()
                        .frame(height: 0.5)
                        .background(Color.gray.opacity(0.3))

                    // MARK: - Tab Content

                    ZStack {
                        switch selectedTab {
                        case .home:
                            ExploreView(posts: $explorePosts)
                                .id(exploreViewID) // force refresh
                        case .messages:
                            YearbookView()
                        case .create:
                            CreateNewPost { newPost in
                                explorePosts = []
                                exploreViewID = UUID()
                                selectedTabRaw = Tab.home.rawValue
                            }
                        case .crown:
                            LeaderboardView()
                        case .profile:
                            ProfileView()
                        }
                    }
                    .navigationBarHidden(true)

                    Divider()
                        .frame(height: 0.5)
                        .background(Color.gray.opacity(0.3))

                    CustomTabBar(selectedTab: Binding(
                        get: { Tab(rawValue: selectedTabRaw) ?? .home },
                        set: { selectedTabRaw = $0.rawValue }
                    ))
                }
                .ignoresSafeArea(.keyboard)

                // MARK: - Overlays

                if showMenu {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation { showMenu = false }
                        }

                    SideDrawerView(
                        activeGroupID: $activeGroupID,
                        showMenu: $showMenu,
                        showJoinModal: $showJoinModal,
                        showCreatePage: $showCreatePage,
                        showGroupsPage: $showGroupsPage
                    )
                    .frame(width: 280)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.move(edge: .leading))
                    .zIndex(1)
                }

                if showJoinModal {
                    JoinGroupModal(isPresented: $showJoinModal)
                        .zIndex(2)
                }

                if showCreatePage {
                    CreateGroupView(isPresented: $showCreatePage)
                        .transition(.move(edge: .trailing))
                        .zIndex(2)
                }

                if showGroupsPage {
                    ViewPublicGroupsView(isPresented: $showGroupsPage)
                        .transition(.move(edge: .trailing))
                        .zIndex(2)
                }
            }
            .navigationDestination(isPresented: $showSearch) {
                UserSearchView()
            }
            .fullScreenCover(isPresented: $showSettings) {
                SettingsView(isPresented: $showSettings)
            }
        }
    }
}

// MARK: - CustomTabBar

struct CustomTabBar: View {
    @Binding var selectedTab: Tab

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.3))

            HStack {
                tabButton(tab: .home, icon: "house")
                tabButton(tab: .messages, icon: "books.vertical")
                tabButton(tab: .create, icon: "plus.app")
                tabButton(tab: .crown, icon: "trophy")
                tabButton(tab: .profile, icon: "person")
            }
            .padding(.top, 15)
            .padding(.bottom, 15)
            .background(Color.white.ignoresSafeArea(edges: .bottom))
        }
    }

    // MARK: - Tab Button

    private func tabButton(tab: Tab, icon: String) -> some View {
        Button(action: {
            selectedTab = tab
        }) {
            VStack(spacing: 4) {
                Image(systemName: selectedTab == tab ? "\(icon).fill" : icon)
                    .font(.system(size: tab == .create ? 26 : 22)) // ✅ larger plus icon
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(selectedTab == tab ? Color("AccentColor") : .secondary)
        }
    }
}
