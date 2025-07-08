import SwiftUI
import SDWebImageSwiftUI
import FirebaseFirestore

// MARK: - UserSearchView
struct UserSearchView: View {
    @ObservedObject var groupsVM: GroupsViewModel
    
    @AppStorage("user_UID") private var userUID: String = ""   // ← uid of current user
    
    @State private var searchText  = ""
    @State private var allUsers    : [User] = []
    @State private var isLoading   = true
    @State private var memberIDs   : [String] = []             // UIDs in active group
    
    private var activeGroupID: String? { groupsVM.activeGroupID }
    
    var body: some View {
        // ✅ we can still use groupMeta for ADMIN information only
        let joinedGroup = groupsVM.myJoinedGroups.first { $0.groupID == activeGroupID }
        let adminID     = joinedGroup?.groupMeta.adminID
        
        VStack(spacing: 0) {
            /* ---------- Search bar ---------- */
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Search", text: $searchText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 10)
            
            /* ---------- Loading ---------- */
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                /* ---------- User list ---------- */
                List {
                    ForEach(filteredUsers()) { user in
                        NavigationLink {
                            ReusableProfileContent(
                                user: user,
                                isMyProfile: false,
                                /* pass the adminID so ReusableProfileContent
                                   can check adminID == userUID internally */
                                selectedGroupAdminID: adminID,
                                activeGroupID: activeGroupID
                            )
                        } label: {
                            HStack(spacing: 12) {
                                WebImage(url: user.userProfileURL)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.username)
                                        .font(.system(size: 15, weight: .semibold))
                                    Text(user.name)
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.plain)
                .padding(.top, 15)
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Task { await loadMembersAndUsers() } }
        .onChange(of: groupsVM.activeGroupID) { _ in
            Task { await loadMembersAndUsers() }
        }
    }
    
    // MARK: - Filtering
    private func filteredUsers() -> [User] {
        let inGroup = allUsers
        guard !searchText.isEmpty else { return inGroup }
        return inGroup.filter {
            $0.username.lowercased().contains(searchText.lowercased()) ||
            $0.name.lowercased().contains(searchText.lowercased())
        }
    }
    
    // MARK: - Load members + their user docs
    private func loadMembersAndUsers() async {
        guard let gid = activeGroupID else {
            await MainActor.run { isLoading = false }
            return
        }
        
        await MainActor.run {
            memberIDs = []
            allUsers  = []
            isLoading = true
        }
        
        let db = Firestore.firestore()
        
        // 1️⃣ Pull the members array from the group document
        do {
            let snap = try await db.collection("Groups").document(gid).getDocument()
            memberIDs = snap.get("members") as? [String] ?? []
        } catch {
            print("Failed to fetch group:", error)
        }
        
        guard !memberIDs.isEmpty else {
            await MainActor.run { isLoading = false }
            return
        }
        
        // 2️⃣ Fetch user docs (≤30 IDs per `in` query)
        var fetched: [User] = []
        for chunk in memberIDs.chunked(into: 30) {
            do {
                let userSnap = try await db.collection("Users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                let users = try userSnap.documents.compactMap { try $0.data(as: User.self) }
                fetched.append(contentsOf: users)
            } catch {
                print("User fetch error:", error)
            }
        }
        
        await MainActor.run {
            allUsers  = fetched
            isLoading = false
        }
    }
}

/* Helper: split arrays into Firestore-legal chunks */
private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
