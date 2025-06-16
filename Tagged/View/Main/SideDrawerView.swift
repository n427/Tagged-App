import SwiftUI

// MARK: - TaggedGroup Model

// Represents a user group with an ID, title, and icon name.
struct TaggedGroup: Identifiable {
    let id = UUID()
    let title: String
    let imageName: String
}

// MARK: - SideDrawerView

// Sidebar menu view for switching groups and navigating to group-related actions.
struct SideDrawerView: View {
    
    // MARK: - Bindings

    @Binding var activeGroupID: UUID
    @Binding var showMenu: Bool
    @Binding var showJoinModal: Bool
    @Binding var showCreatePage: Bool
    @Binding var showGroupsPage: Bool

    // MARK: - Mock Group List (Replace with dynamic data in production)

    let groups: [TaggedGroup] = [
        TaggedGroup(title: "Sentinel Gifted", imageName: "person.crop.circle.fill"),
        TaggedGroup(title: "Math Contests", imageName: "person.crop.circle.fill"),
        TaggedGroup(title: "Dance Club", imageName: "person.crop.circle.fill"),
        TaggedGroup(title: "AP Calc BC", imageName: "person.crop.circle.fill"),
        TaggedGroup(title: "Grad 2025", imageName: "person.crop.circle.fill")
    ]

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

            Divider().padding(.bottom, 6)

            // MARK: - Group List Section

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(groups) { group in
                        Button(action: {
                            activeGroupID = group.id
                            showMenu = false
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: group.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.gray)

                                Text(group.title)
                                    .font(.system(size: 15, weight: .medium))

                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(
                                activeGroupID == group.id
                                    ? Color.gray.opacity(0.12)
                                    : Color.clear
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
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
