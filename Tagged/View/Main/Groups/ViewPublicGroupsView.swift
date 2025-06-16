import SwiftUI

// MARK: - Model for Public Group
struct PublicGroup: Identifiable {
    let id = UUID() // Unique identifier for each group
    let imageName: String // Placeholder for image asset name
    let name: String // Group title
    let description: String // Group description
}

// MARK: - Main View
struct ViewPublicGroupsView: View {
    @State private var searchText = "" // Search field binding
    @Binding var isPresented: Bool // Controls whether the view is shown

    // Dummy group data
    let groups: [PublicGroup] = [
        PublicGroup(imageName: "photo", name: "Photography Club", description: "Weekly photo prompts"),
        PublicGroup(imageName: "photo", name: "Study Buddies", description: "Focus accountability group group group group group group group group group group group group "),
        PublicGroup(imageName: "photo", name: "Art Prompts", description: "Share your art each week")
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)

                    TextField("Search for a group", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 15)

                // MARK: - Group List
                ScrollView {
                    VStack(spacing: 12) {
                        // Filter groups based on search text
                        ForEach(groups.filter {
                            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
                        }) { group in
                            HStack(alignment: .top, spacing: 12) {
                                // MARK: - Group Image Placeholder
                                ZStack {
                                    Color.gray.opacity(0.1) // Light gray background
                                    Image(systemName: "camera")
                                        .font(.system(size: 24))
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 60, height: 60)
                                .cornerRadius(6)

                                // MARK: - Group Info (Name + Description)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(group.name)
                                        .font(.headline)

                                    Text(group.description)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .fixedSize(horizontal: false, vertical: true) // Allow multiline description
                                }

                                Spacer()

                                // MARK: - Join Button (Vertically Centered)
                                VStack {
                                    Spacer()
                                    Button("Join") {
                                        isPresented = false // Dismiss view when joined
                                    }
                                    .font(.subheadline)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    Spacer()
                                }
                            }
                            .padding()
                            .background(
                                // Outline around each group block
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .padding(.top, 3)
                .refreshable {} // Pull to refresh placeholder
            }

            // MARK: - Navigation Bar Setup
            .navigationTitle("Public Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false // Dismiss on cancel
                    }
                }
            }
        }
    }
}
