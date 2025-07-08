import SwiftUI
import FirebaseFirestore

// MARK: - Tab Enum
enum Tab: String {
    case home, messages, create, crown, profile
}

// MARK: - Main View
struct MainView: View {
    // MARK: - AppStorage & State
    @AppStorage("selected_tab") private var selectedTabRaw: String = Tab.home.rawValue
    @AppStorage("user_UID") private var userUID: String = ""

    @State private var showMenu = false
    @State private var showCreatePage = false
    @State private var showJoinModal = false
    @State private var showGroupsPage = false
    @State private var showSearch = false
    @State private var showSettings = false
    @State private var explorePosts: [Post] = []
    @State private var exploreViewID = UUID()
    @State private var hasSetInitialGroup = false

    @StateObject private var groupsVM = GroupsViewModel(userUID: UserDefaults.standard.string(forKey: "user_UID") ?? "")

    var isAdminOfActiveGroup: Bool {
        guard
            let activeID = groupsVM.activeGroupID,
            let group = groupsVM.myJoinedGroups.first(where: { $0.groupID == activeID })
        else { return false }

        return group.groupMeta.adminID == userUID
    }

    var selectedTab: Tab {
        get { Tab(rawValue: selectedTabRaw) ?? .home }
        set { selectedTabRaw = newValue.rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    HeaderView(
                        showMenu: $showMenu,
                        showSearch: $showSearch,
                        showSettings: $showSettings,
                        isAdmin: isAdminOfActiveGroup
                    )

                    Divider().frame(height: 0.5).background(Color.gray.opacity(0.3))

                    // MARK: - Tab Content
                    ZStack {
                        switch selectedTab {
                        case .home:
                            ExploreView(activeGroupID: groupsVM.activeGroupID)
                                .id(groupsVM.activeGroupID)
                        case .messages:
                            LeaderboardView(groupsVM: groupsVM)
                        case .create:
                            CreateNewPost(groupsVM: groupsVM) { _ in
                                explorePosts = []
                                exploreViewID = UUID()
                                selectedTabRaw = Tab.home.rawValue
                            }
                        case .crown:
                            LeaderboardView(groupsVM: groupsVM)
                        case .profile:
                            ProfileView(groupsVM: groupsVM, activeGroupID: groupsVM.activeGroupID)
                        }
                    }
                    .navigationBarHidden(true)

                    Divider().frame(height: 0.5).background(Color.gray.opacity(0.3))

                    CustomTabBar(selectedTab: Binding(
                        get: { selectedTab },
                        set: { selectedTabRaw = $0.rawValue }
                    ))
                }
                .ignoresSafeArea(.keyboard)

                // MARK: - Overlays
                if showMenu {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { showMenu = false } }

                    SideDrawerView(
                        groupsVM: groupsVM,
                        activeGroupID: $groupsVM.activeGroupID,
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
                    JoinGroupModal(isPresented: $showJoinModal, groupsVM: groupsVM).zIndex(2)
                }

                if showCreatePage {
                    CreateGroupView(isPresented: $showCreatePage)
                        .transition(.move(edge: .trailing))
                        .zIndex(2)
                }

                if showGroupsPage {
                    ViewPublicGroupsView(isPresented: $showGroupsPage, groupsVM: groupsVM)
                        .transition(.move(edge: .trailing))
                        .zIndex(2)
                }
            }
            .navigationDestination(isPresented: $showSearch) {
                UserSearchView(groupsVM: groupsVM)
            }
            .fullScreenCover(isPresented: $showSettings) {
                SettingsView(isPresented: $showSettings, groupsVM: groupsVM)
            }
        }

        .task {
            if !hasSetInitialGroup, let first = groupsVM.myJoinedGroups.first {
                groupsVM.activeGroupID = first.groupID
                hasSetInitialGroup = true
            }
            
            // Wait for groups to fully populate
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await groupsVM.resetMissedStreaksIfNeeded()
        }


        .onChange(of: groupsVM.myJoinedGroups) { newGroups in
            if !hasSetInitialGroup, let first = newGroups.first {
                groupsVM.activeGroupID = first.groupID
                hasSetInitialGroup = true
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
