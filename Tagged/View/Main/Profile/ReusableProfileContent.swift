import SwiftUI
import SDWebImageSwiftUI
import Firebase
import FirebaseFirestore

struct ReusableProfileContent: View {
    @State var user: User
    var isMyProfile: Bool
    var selectedGroupAdminID: String? = nil
    var activeGroupID: String? = nil
    var logOutAction: (() -> Void)? = nil
    var deleteAccountAction: (() -> Void)? = nil
    var onUpdate: (() -> Void)? = nil

    @State private var currentStreak: Int?
    @State private var currentPoints: Int?
    @State private var statsListener: ListenerRegistration?

    @State private var fetchedPosts: [Post] = []
    @State private var isContentReady = false
    @State private var isFetching = false
    @State private var paginationDoc: QueryDocumentSnapshot?
    @State private var showSettings   = false
    @State private var hasLoaded = false
    @State private var lastGroupID: String?


    var userUIDForRefresh: String {
        user.userUID
    }


    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        ZStack {
            if !isContentReady {
                VStack {
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.accentColor.opacity(0.05))
                            .frame(width: 40, height: 40)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.accentColor))
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .task {
                    if let gid = activeGroupID, !gid.isEmpty {
                        await initialLoad()
                        listenToGroupStats()
                    } else {
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        Text(user.username)
                            .font(.system(size: 28, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 20)
                            .padding(.horizontal)
                        
                        HStack(alignment: .top, spacing: 16) {
                            WebImage(url: user.userProfileURL)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(user.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                HStack(spacing: 35) {
                                    statView("\(fetchedPosts.count)", "posts")
                                    statView("\(fetchedPosts.reduce(0) { $0 + $1.likedIDs.count })", "likes")
                                    statView(currentPoints != nil ? "\(currentPoints!)" : "0", "points")
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        if let adminID = selectedGroupAdminID, adminID == user.userUID {
                            Text("Admin")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundColor(.accentColor)
                                .cornerRadius(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                        }
                        
                        HStack(spacing: 0) {
                            if let streak = currentStreak {
                                Text("🔥 \(streak)-week")
                                    .foregroundColor(.accentColor)
                                    .fontWeight(.semibold)
                            } else {
                                Text("🔥 0-week")
                                    .foregroundColor(.accentColor)
                                    .fontWeight(.semibold)
                            }
                            Text(" streak")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        
                        HStack {
                            Text(user.userBio)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, -10)
                        
                        if isMyProfile {
                            HStack(spacing: 16) {
                                NavigationLink {
                                    EditProfileView(onUpdate: { onUpdate?() })
                                } label: {
                                    Text("Edit Profile")
                                }
                                .buttonStyle(OutlineButtonStyle())
                                
                                profileButton("Settings") { showSettings.toggle() }
                                    .confirmationDialog("Settings", isPresented: $showSettings) {
                                        Button { logOutAction?() }  label: { Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right") }
                                        Button(role: .destructive) { deleteAccountAction?() } label: { Label("Delete Account", systemImage: "trash") }
                                    }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 5)
                        }
                        
                        Divider().padding(.horizontal).padding(.bottom, 5)
                        
                        if fetchedPosts.isEmpty {
                            Text("No Posts Yet!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .frame(maxHeight: .infinity)
                        } else {
                            LazyVGrid(columns: columns, spacing: 4) {
                                ForEach(fetchedPosts) { post in
                                    ZStack {
                                        NavigationLink {
                                            PostDetailView(
                                                post: post,
                                                onUpdate: { updated in
                                                    if let i = fetchedPosts.firstIndex(where: { $0.id == updated.id }) {
                                                        fetchedPosts[i].likedIDs = updated.likedIDs
                                                    }
                                                },
                                                onDelete: {
                                                    withAnimation(.easeInOut(duration: 0.25)) {
                                                        fetchedPosts.removeAll { $0.id == post.id }
                                                    }
                                                }
                                            )
                                        } label: {
                                            WebImage(url: post.imageURL)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: tileSize, height: tileSize)
                                                .clipped()
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .frame(width: tileSize, height: tileSize)
                                    .contentShape(Rectangle())
                                    .id(post.id)
                                    .onAppear {
                                        if post.id == fetchedPosts.last?.id, paginationDoc != nil {
                                            Task { await fetchPosts() }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 15)
                            .padding(.bottom, 20)
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .transition(.opacity)
                .task {
                    guard !hasLoaded else { return }
                    hasLoaded = true
                    
                    statsListener?.remove()
                    statsListener = nil
                    
                    await initialLoad()
                    listenToGroupStats()
                    await refreshProfileIfNeeded()
                }
                .onAppear {
                    Task { await refreshProfileIfNeeded() }
                }

                
                .onDisappear {
                    statsListener?.remove()
                    statsListener = nil
                }
                .onChange(of: activeGroupID) {
                    Task {
                        statsListener?.remove()
                        statsListener = nil
                        
                        isContentReady = false
                        fetchedPosts = []
                        currentPoints = nil
                        currentStreak = nil
                        paginationDoc = nil
                        hasLoaded = false
                        
                        await initialLoad()
                        listenToGroupStats()
                    }
                }
                
                .refreshable {
                    paginationDoc = nil
                    await fetchUser()
                    await fetchPosts(isRefresh: true)
                    await fetchGroupStats()
                }
                
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isContentReady)
    }

    private func fetchUser() async {
        do {
            let doc = try await Firestore.firestore()
                .collection("Users")
                .document(userUIDForRefresh)
                .getDocument(as: User.self)

            await MainActor.run {
                self.user = doc
            }
        } catch {
        }
    }

    
    private func profileButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action).buttonStyle(OutlineButtonStyle())
    }
    
    private var tileSize: CGFloat {
        let screen = UIScreen.main.bounds.width
        let margins: CGFloat = 25 * 2
        let spacing: CGFloat = 4 * 2
        return (screen - margins - spacing) / 3
    }

    private func statView(_ number: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(number).bold()
            Text(label).font(.footnote)
        }
    }

    private func initialLoad() async {
        var statsLoaded = false
        var postsLoaded = false

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await fetchGroupStats()
                statsLoaded = true
            }
            group.addTask {
                await fetchPosts()
                postsLoaded = true
            }

            for await _ in group {}
        }

        await MainActor.run {
            isContentReady = statsLoaded && postsLoaded
        }

        if !statsLoaded {
        }
        if !postsLoaded {
        }
    }


    private func reloadPosts() async {
        paginationDoc = nil
        await fetchPosts(isRefresh: true)
    }

    private func fetchPosts(isRefresh: Bool = false) async {
        do {
            var query = Firestore.firestore()
                .collection("Posts")
                .order(by: "publishedDate", descending: true)
                .limit(to: 20)

            if let last = paginationDoc {
                query = query.start(afterDocument: last)
            }

            query = query
                .whereField("userUID", isEqualTo: user.userUID)
                .whereField("groupID", isEqualTo: activeGroupID ?? "")

            let snap = try await query.getDocuments()
            let posts = snap.documents.compactMap { try? $0.data(as: Post.self) }

            await MainActor.run {
                if isRefresh {
                    fetchedPosts = posts
                } else {
                    fetchedPosts.append(contentsOf: posts)
                }
                paginationDoc = snap.documents.last
            }
        } catch {
        }
    }

    private func fetchGroupStats() async {
        guard let gid = activeGroupID, !gid.isEmpty else {
            return
        }

        do {
            let doc = try await Firestore.firestore()
                .collection("Users").document(user.userUID)
                .collection("JoinedGroups").document(gid)
                .getDocument()

            let streak = doc["streak"] as? Int
            let points = doc["points"] as? Int

            await MainActor.run {
                currentStreak = streak
                currentPoints = points
            }
        } catch {
        }
    }

    private func listenToGroupStats() {
        guard let gid = activeGroupID, !gid.isEmpty else { return }

        if statsListener != nil { return }

        statsListener = Firestore.firestore()
            .collection("Users").document(user.userUID)
            .collection("JoinedGroups").document(gid)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data(), error == nil else { return }

                let points = data["points"] as? Int ?? 0
                let streak = data["streak"] as? Int ?? 0

                if isContentReady {
                    Task {
                        await MainActor.run {
                            self.currentPoints = points
                            self.currentStreak = streak
                        }
                    }
                }
            }
    }
    private func refreshProfileIfNeeded() async {
        guard let gid = activeGroupID, !gid.isEmpty else { return }

        if gid != lastGroupID || !hasLoaded {
            lastGroupID = gid
            hasLoaded = true

            statsListener?.remove()
            statsListener = nil

            await MainActor.run {
                isContentReady = false
                fetchedPosts = []
                currentPoints = nil
                currentStreak = nil
                paginationDoc = nil
            }

            await initialLoad()
            listenToGroupStats()
        }
    }

}

private struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.accentColor, lineWidth: 1)
                    .opacity(configuration.isPressed ? 0.4 : 1)
            )
    }
}
