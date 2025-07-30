import SwiftUI
import FirebaseFirestore
import SDWebImageSwiftUI

struct ViewPublicGroupsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var groupsVM: GroupsViewModel

    @State private var searchText = ""
    @State private var groups: [Group] = []
    @State private var isLoading = false
    @State private var showContent = false

    var filteredGroups: [Group] {
        if searchText.isEmpty {
            return groups
        } else {
            return groups.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }

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
        ZStack {
            NavigationView {
                VStack(spacing: 0) {

                    searchBar

                    ScrollView {
                        VStack(spacing: 12) {
                            if isLoading {
                                EmptyView()
                            } else if filteredGroups.isEmpty {
                                Text("No Groups Found")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .frame(maxHeight: .infinity)
                            } else {
                                groupList
                            }
                        }
                        .padding(.vertical)
                    }
                    .padding(.top, 3)
                    .refreshable { await fetchExploreGroups() }
                }
                .opacity(showContent ? 1 : 0)
                .animation(.easeIn(duration: 0.4), value: showContent)
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
        if isLoading {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accentColor.opacity(0.05))
                    .frame(width: 40, height: 40)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.accentColor))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .animation(.easeOut(duration: 0.2), value: isLoading)
        }
    }

    func fetchExploreGroups() async {
        await MainActor.run {
            isLoading = true
            showContent = false
        }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("Groups")
                .whereField("isPlayMode", isEqualTo: false)
                .getDocuments()


            let fetchedGroups = snapshot.documents.compactMap { doc -> Group? in
                do {
                    var group = try doc.data(as: Group.self)
                    group.id = doc.documentID
                    return group
                } catch {
                    return nil
                }
            }

            await MainActor.run {
                self.groups = fetchedGroups
                self.isLoading = false
                withAnimation(.easeIn(duration: 0.4)) {
                    self.showContent = true
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                showContent = false
            }
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
