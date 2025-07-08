import SwiftUI
import FirebaseFirestore
import SDWebImageSwiftUI

// MARK: - Main View
struct ViewPublicGroupsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var groupsVM: GroupsViewModel
    
    @State private var searchText = ""
    @State private var groups: [Group] = []

    var filteredGroups: [Group] {
        if searchText.isEmpty {
            return groups
        } else {
            return groups.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }

    // MARK: - Sub-views
    private var searchBar: some View {
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
    }

    @ViewBuilder
    private var groupList: some View {
        ForEach(filteredGroups) { group in
            let alreadyJoined = groupsVM.myJoinedGroups.contains { $0.id == group.id }

            PublicGroupRow(group: group,
                           isAlreadyJoined: alreadyJoined) {
                Task {
                    if !alreadyJoined { await groupsVM.join(group) }
                    isPresented = false
                }
            }
        }
    }

    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // MARK: Search Bar
                searchBar

                // MARK: Group List
                ScrollView {
                    VStack(spacing: 12) {
                        if filteredGroups.isEmpty {
                            Text("❌ No groups found or failed to decode.")
                                .foregroundColor(.red)
                                .padding()
                        } else {
                            groupList
                        }
                    }
                    .padding(.vertical)
                }
                .padding(.top, 3)
                .refreshable { await fetchExploreGroups() }
            }
            .navigationTitle("Public Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
        .task { await fetchExploreGroups() }
    }


    func fetchExploreGroups() async {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("Groups")
                .whereField("isPlayMode", isEqualTo: false)
                .getDocuments()

            print("📦 Fetched groups count: \(snapshot.documents.count)")

            let fetchedGroups = snapshot.documents.compactMap { doc -> Group? in
                do {
                    var group = try doc.data(as: Group.self)
                    group.id = doc.documentID
                    print("✅ Decoded group: \(group.title), id: \(group.id ?? "nil")")
                    return group
                } catch {
                    print("❌ Failed to decode document: \(doc.documentID), error: \(error)")
                    return nil
                }
            }

            await MainActor.run {
                print("🧮 Groups assigned to state: \(fetchedGroups.count)")
                self.groups = fetchedGroups
            }
        } catch {
            print("❌ Firestore query error: \(error.localizedDescription)")
        }
    }
}

struct PublicGroupRow: View {
    let group: Group
    let isAlreadyJoined: Bool
    let joinAction: () -> Void

    var body: some View {
        GroupCard(group: group,
                  isAlreadyJoined: isAlreadyJoined,
                  onJoin: joinAction)
    }
}


// MARK: - Group Card
struct GroupCard: View {
    let group: Group
    let isAlreadyJoined: Bool
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
                Button(action: onJoin) {
                    HStack {
                        Image(systemName: isAlreadyJoined ? "checkmark.circle" : "plus")
                        Text(isAlreadyJoined ? "Already Joined" : "Join")
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(isAlreadyJoined ? Color.gray : Color.accentColor)
                    .cornerRadius(6)
                }
                .disabled(isAlreadyJoined)

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
