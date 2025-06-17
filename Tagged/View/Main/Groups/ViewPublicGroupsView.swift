import SwiftUI
import FirebaseFirestore
import SDWebImageSwiftUI

// MARK: - Main View
struct ViewPublicGroupsView: View {
    @State private var searchText = "" // Search field binding
    @Binding var isPresented: Bool // Controls whether the view is shown
    
    @State private var groups: [Group] = []
    
    var filteredGroups: [Group] {
        if searchText.isEmpty {
            return groups
        } else {
            return groups.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
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
                        ForEach(filteredGroups) { group in
                            GroupCard(group: group) {
                                isPresented = false
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .padding(.top, 3)
                .refreshable {await fetchExploreGroups()} // Pull to refresh placeholder
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
        .task {
            await fetchExploreGroups()
        }
    }
    
    func fetchExploreGroups() async {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("Groups")
                .whereField("isPlayMode", isEqualTo: false)
                .getDocuments()

            let fetchedGroups = snapshot.documents.compactMap { doc -> Group? in
                try? doc.data(as: Group.self)
            }

            await MainActor.run {
                groups = fetchedGroups
            }
        } catch {
            print("❌ Error fetching groups: \(error.localizedDescription)")
        }
    }

}

struct GroupCard: View {
    let group: Group
    let onJoin: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            WebImage(url: group.imageURL)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(group.title)
                    .font(.headline)

                Text(group.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack {
                Spacer()
                Button("Join", action: onJoin)
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
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

