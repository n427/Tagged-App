import SwiftUI
import SDWebImageSwiftUI
import FirebaseFirestore

enum Tab: String {
    case home, messages, create, crown, profile
}

struct MainTabContent: View {
    @State private var selectedTab: Tab = .home
    @State private var showMenu = false
    @State private var showCreatePage = false
    @State private var showJoinModal = false
    @State private var showGroupsPage = false
    @State private var showSearch = false
    @State private var showSettings = false
    @State private var explorePosts: [Post] = []
    @State private var exploreViewID = UUID()

    let userUID: String
    @ObservedObject var groupsVM: GroupsViewModel

    var isAdminOfActiveGroup: Bool {
        guard
            let activeID = groupsVM.activeGroupID,
            let group = groupsVM.myJoinedGroups.first(where: { $0.groupID == activeID })
        else { return false }

        return group.groupMeta.adminID == userUID
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    HeaderView(
                        showMenu: $showMenu,
                        showSearch: $showSearch,
                        showSettings: $showSettings,
                        isAdmin: isAdminOfActiveGroup,
                        onLeave: {
                            Task {
                                if let groupID = groupsVM.activeGroupID {
                                    await groupsVM.leave(groupID: groupID, userUID: userUID)
                                }
                            }
                        }
                    )

                    Divider().frame(height: 0.5).background(Color.gray.opacity(0.3))

                    ZStack {
                        if let activeID = groupsVM.activeGroupID {
                            ExploreView(activeGroupID: activeID, groupsVM: groupsVM)
                                .id(activeID)
                                .opacity(selectedTab == .home ? 1 : 0)
                        } else {
                            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        YearbookView(activeGroupID: groupsVM.activeGroupID)
                            .id(groupsVM.activeGroupID)
                            .opacity(selectedTab == .messages ? 1 : 0)

                        CreateNewPost(groupsVM: groupsVM) { _ in
                            explorePosts = []
                            exploreViewID = UUID()
                            selectedTab = .home
                        }
                        .opacity(selectedTab == .create ? 1 : 0)

                        LeaderboardView(groupsVM: groupsVM)
                            .opacity(selectedTab == .crown ? 1 : 0)

                        ProfileView(groupsVM: groupsVM, activeGroupID: groupsVM.activeGroupID)
                            .opacity(selectedTab == .profile ? 1 : 0)
                    }
                    .navigationBarHidden(true)

                    Divider().frame(height: 0.5).background(Color.gray.opacity(0.3))

                    CustomTabBar(selectedTab: $selectedTab)
                }
                .ignoresSafeArea(.keyboard)

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
                    CreateGroupView(isPresented: $showCreatePage, groupsVM: groupsVM)
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

    private func tabButton(tab: Tab, icon: String) -> some View {
        Button(action: {
            selectedTab = tab
        }) {
            VStack(spacing: 4) {
                Image(systemName: selectedTab == tab ? "\(icon).fill" : icon)
                    .font(.system(size: tab == .create ? 26 : 22)) 
                    .fontWeight(.light)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(selectedTab == tab ? Color("AccentColor") : .black)
        }
    }
}
