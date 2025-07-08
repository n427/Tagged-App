import SwiftUI
import SDWebImageSwiftUI
import Firebase
import FirebaseFirestore

// MARK: - ReusableProfileContent
struct ReusableProfileContent: View {
    // MARK: - Injected & State
    @State var user: User
    var isMyProfile: Bool
    var selectedGroupAdminID: String? = nil
    var activeGroupID: String? = nil
    var logOutAction: (() -> Void)? = nil
    var deleteAccountAction: (() -> Void)? = nil
    var onUpdate: (() -> Void)? = nil
    
    // Stats
    @State private var currentStreak:  Int? = nil
    @State private var currentPoints:  Int? = nil          // ← NEW
    
    // UI
    @State private var showSettings   = false
    @State private var fetchedPosts   : [Post] = []
    @State private var isFetching     = false
    @State private var paginationDoc  : QueryDocumentSnapshot?
    
    // 3-column grid
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
    
    var body: some View {
        GeometryReader { _ in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    
                    // MARK: Profile Header
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
                                .truncationMode(.tail)
                            
                            HStack(spacing: 35) {
                                statView("\(fetchedPosts.count)",                                    "posts")
                                statView("\(fetchedPosts.reduce(0) { $0 + ($1.likedIDs.count ?? 0) })","likes")
                                statView("\(currentPoints ?? 0)",                                    "points") // ← UPDATED
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    if let adminID = selectedGroupAdminID, adminID == user.userUID {
                        Text("Admin")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                    
                    HStack(spacing: 0) {
                        Text("🔥 \(currentStreak ?? 0)-week")
                            .foregroundColor(.accentColor)
                            .fontWeight(.semibold)
                        
                        Text(" streak")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // MARK: Bio
                    HStack {
                        Text(user.userBio)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, -10)
                    
                    // MARK: Buttons
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
                                    Button { logOutAction?() }  label: { Label("Log Out",    systemImage: "rectangle.portrait.and.arrow.right") }
                                    Button(role: .destructive)  { deleteAccountAction?() } label: { Label("Delete Account", systemImage: "trash") }
                                }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 5)
                    }
                    
                    Divider().padding(.horizontal).padding(.bottom, 5)
                    
                    // MARK: Grid of Posts
                    if isFetching {
                        ProgressView().padding(.top, 30)
                    } else if fetchedPosts.isEmpty {
                        Text("No Posts Found")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 30)
                    } else {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(fetchedPosts) { post in
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
            .ignoresSafeArea(.container, edges: .bottom)
            .task { await initialLoad() }
            .onChange(of: activeGroupID) { _ in Task { await fetchGroupStats() } }
            .refreshable {
                fetchedPosts = []; paginationDoc = nil
                await fetchUserData()
                await fetchPosts()
            }
        }
        .padding(.top, -15)
    }
    
    // MARK: Helpers -----------------------------------------------------------
    private var tileSize: CGFloat {
        let screen = UIScreen.main.bounds.width
        let margins: CGFloat = 25 * 2   // outer padding in parent view
        let spacing: CGFloat = 4 * 2    // inner grid spacing
        return (screen - margins - spacing) / 3
    }
    
    private func statView(_ number: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(number).bold()
            Text(label).font(.footnote)
        }
    }
    
    private func profileButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action).buttonStyle(OutlineButtonStyle())
    }
    
    // MARK: Firestore Ops ------------------------------------------------------
    private func initialLoad() async {
        guard fetchedPosts.isEmpty else { return }
        await fetchPosts()
        await fetchGroupStats()
    }
    
    private func fetchPosts() async {
        await MainActor.run { isFetching = true }
        defer { Task { await MainActor.run { isFetching = false } } }
        
        do {
            var query: Query = Firestore.firestore()
                .collection("Posts")
                .order(by: "publishedDate", descending: true)
                .limit(to: 20)
            
            if let last = paginationDoc { query = query.start(afterDocument: last) }
            query = query
                .whereField("userUID",  isEqualTo: user.userUID)
                .whereField("groupID", isEqualTo: activeGroupID ?? "")
            
            let snap  = try await query.getDocuments()
            let posts = snap.documents.compactMap { try? $0.data(as: Post.self) }
            
            await MainActor.run {
                fetchedPosts.append(contentsOf: posts)
                paginationDoc = snap.documents.last
            }
        } catch {
            print("❌ fetchPosts:", error.localizedDescription)
        }
    }
    
    /// Pull `streak` **and** `points` from `Users/{uid}/JoinedGroups/{gid}`.
    private func fetchGroupStats() async {
        guard let gid = activeGroupID, !gid.isEmpty else { return }
        
        do {
            let doc = try await Firestore.firestore()
                .collection("Users").document(user.userUID)
                .collection("JoinedGroups").document(gid)
                .getDocument()
            
            let streak  = doc["streak"]  as? Int ?? 0
            let points  = doc["points"]  as? Int ?? 0
            
            await MainActor.run {
                currentStreak = streak
                currentPoints = points
            }
        } catch {
            print("❌ fetchGroupStats:", error.localizedDescription)
        }
    }
    
    private func fetchUserData() async {
        do {
            let refreshed = try await Firestore.firestore()
                .collection("Users").document(user.userUID)
                .getDocument(as: User.self)
            await MainActor.run { user = refreshed }
        } catch {
            print("❌ refresh user:", error.localizedDescription)
        }
    }
}

// MARK: - Simple Outline Button style used above
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
