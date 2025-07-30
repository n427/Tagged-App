import SwiftUI
import SDWebImageSwiftUI
import FirebaseFirestore

struct UserSearchView: View {
    @ObservedObject var groupsVM: GroupsViewModel
    
    @AppStorage("user_UID") private var userUID: String = ""
    
    @State private var searchText  = ""
    @State private var allUsers    : [User] = []
    @State private var isLoading   = true
    @State private var memberIDs   : [String] = []
    private var activeGroupID: String? { groupsVM.activeGroupID }
    
    var body: some View {
        let joinedGroup = groupsVM.myJoinedGroups.first { $0.groupID == activeGroupID }
        let adminID     = joinedGroup?.groupMeta.adminID
        
        VStack(spacing: 0) {
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
            
            if isLoading {
                VStack {
                    Spacer()

                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.accentColor.opacity(0.05))
                            .frame(width: 40, height: 40)

                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.accentColor))
                            .scaleEffect(1)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else {
                List {
                    ForEach(filteredUsers()) { user in
                        NavigationLink {
                            ReusableProfileContent(
                                user: user,
                                isMyProfile: false,
                                selectedGroupAdminID: adminID,
                                activeGroupID: activeGroupID
                            )

                        }
                        label: {
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
        .onChange(of: groupsVM.activeGroupID) {
            Task { await loadMembersAndUsers() }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: isLoading)
    }
    
    private func filteredUsers() -> [User] {
        let inGroup = allUsers
        guard !searchText.isEmpty else { return inGroup }
        return inGroup.filter {
            $0.username.lowercased().contains(searchText.lowercased()) ||
            $0.name.lowercased().contains(searchText.lowercased())
        }
    }
    
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
        
        do {
            let snap = try await db.collection("Groups").document(gid).getDocument()
            memberIDs = snap.get("members") as? [String] ?? []
        } catch {
        }
        
        guard !memberIDs.isEmpty else {
            await MainActor.run { isLoading = false }
            return
        }
        
        var fetched: [User] = []
        for chunk in memberIDs.chunked(into: 30) {
            do {
                let userSnap = try await db.collection("Users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                let users = try userSnap.documents.compactMap { try $0.data(as: User.self) }
                fetched.append(contentsOf: users)
            } catch {
            }
        }
        
        await MainActor.run {
            allUsers  = fetched
            isLoading = false
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
