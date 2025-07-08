import SwiftUI
import SDWebImageSwiftUI
import FirebaseFirestore

// MARK: - SideDrawerView

// Sidebar menu view for switching groups and navigating to group-related actions.
struct SideDrawerView: View {
    
    @ObservedObject var groupsVM: GroupsViewModel
    @Binding var activeGroupID: String?
    @Binding var showMenu: Bool
    @Binding var showJoinModal: Bool
    @Binding var showCreatePage: Bool
    @Binding var showGroupsPage: Bool
    
    @AppStorage("user_UID") private var userUID: String = ""

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: - Top Action Buttons

            VStack(alignment: .leading, spacing: 12) {
                GroupActionButton(
                    icon: "plus",
                    title: "Start a Group",
                    action: {
                        showMenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showCreatePage = true
                        }
                    }
                )

                GroupActionButton(
                    icon: "person.2.fill",
                    title: "Join a Group",
                    action: {
                        showMenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showJoinModal = true
                        }
                    }
                )

                GroupActionButton(
                    icon: "magnifyingglass",
                    title: "Public Groups",
                    action: {
                        showMenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showGroupsPage = true
                        }
                    }
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 10)

            Divider()

            // MARK: - Group List Section

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(sortedGroups) { joined in
                        let group = joined.groupMeta

                        Button {
                            // 1) activate locally
                            activeGroupID = group.id
                            showMenu = false

                            // 2) update lastOpened in Firestore
                            Task {
                                try? await Firestore.firestore()
                                    .collection("Users")
                                    .document(userUID)
                                    .collection("JoinedGroups")
                                    .document(group.id ?? "")
                                    .updateData(["lastOpened": FieldValue.serverTimestamp()])
                            }
                        } label: {
                            HStack(spacing: 12) {
                                WebImage(url: group.imageURL)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 30, height: 30)
                                    .clipShape(Circle())

                                Text(group.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(
                                (activeGroupID != nil && activeGroupID == group.id) ?
                                    Color.accentColor.opacity(0.15) : Color.clear
                            )
                        }
                    }
                }
            }
            .refreshable {
                await groupsVM.refreshJoinedGroups()   // simple `getDocuments()`
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
    }

    // MARK: - Helpers

    private var sortedGroups: [JoinedGroup] {
        groupsVM.myJoinedGroups.sorted { (a: JoinedGroup, b: JoinedGroup) in
            let dateA = a.lastOpened?.dateValue() ?? Date.distantPast
            let dateB = b.lastOpened?.dateValue() ?? Date.distantPast
            return dateA > dateB
        }
    }
}

// MARK: - GroupActionButton

// Reusable sidebar button for triggering group-related actions.
struct GroupActionButton: View {
    var icon: String
    var title: String
    var iconSize: CGFloat = 18
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .frame(width: 18) // Ensures all icons align horizontally

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
            }
            .foregroundColor(.accentColor)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
