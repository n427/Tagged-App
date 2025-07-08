import SwiftUI
import SDWebImageSwiftUI
import FirebaseFirestore

// MARK: - LeaderboardEntry
struct LeaderboardEntry: Identifiable {
    let id: String
    let user: User
    let points: Int
    let likes: Int      // per-group likes
    let streak: Int
}

// MARK: - LeaderboardView
struct LeaderboardView: View {

    // Inject the shared GroupsViewModel so we know the active group.
    @ObservedObject var groupsVM: GroupsViewModel
    @AppStorage("user_UID") private var userUID: String = ""

    private var activeGroupID: String? { groupsVM.activeGroupID }
    private var adminID: String? {
        groupsVM.myJoinedGroups.first { $0.groupID == activeGroupID }?.groupMeta.adminID
    }

    @State private var entries:   [LeaderboardEntry] = []
    @State private var isLoading: Bool               = true

    private let accent = Color.accentColor

    // MARK: - View
    // MARK: - View
    var body: some View {
        ZStack(alignment: .top) {

            // ---------- Loader (covers entire screen) ----------
            if isLoading {
                Color(.systemBackground)            // keep the same background
                    .ignoresSafeArea()
                ProgressView()
                    .padding(.top, 20)
                    .scaleEffect(1.3)               // bigger spinner
            }

            // ---------- Real content (only appears when loaded) ----------
            if !isLoading {
                VStack(spacing: 24) {

                    // Podium
                    if !entries.isEmpty { podiumSection }

                    Divider().padding(.horizontal, 25)

                    // Ranked list
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                leaderboardRow(rank: index + 1, entry: entry)
                            }
                        }
                        .padding(.horizontal, 25)
                        .padding(.bottom, 40)
                    }
                }
                .padding(.top, 12)
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Task { await loadLeaderboard() } }
        .onChange(of: groupsVM.activeGroupID) { _ in
            Task { await loadLeaderboard() }
        }
    }
}

// MARK: - UI builders
private extension LeaderboardView {

    /// Skeleton placeholder for loading state
    var skeletonEntry: LeaderboardEntry {
        LeaderboardEntry(
                id: "skeleton",
                user: User(
                    id: nil,
                    username: "loading...",
                    name: "",
                    userBio: "",
                    userUID: "",
                    userEmail: "",
                    userProfileURL: nil,
                    userLikeCount: 0
                ),
                points: 0,
                likes: 0,
                streak: 0
            )
    }

    // Podium section
    var podiumSection: some View {
        let top3 = Array(entries.prefix(3))
        return HStack(alignment: .bottom, spacing: 24) {
            podiumColumn(rank: 2, entry: top3[safe: 1], height: 100, color: accent.opacity(0.6))
            podiumColumn(rank: 1, entry: top3[safe: 0], height: 140, color: accent)
            podiumColumn(rank: 3, entry: top3[safe: 2], height: 80,  color: accent.opacity(0.6))
        }
        .padding(.top, 20)
    }

    // Single podium column
    func podiumColumn(rank: Int, entry: LeaderboardEntry?, height: CGFloat, color: Color) -> some View {
        VStack(spacing: 10) {
            if let entry {
                WebImage(url: entry.user.userProfileURL)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 55, height: 55)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 55, height: 55)
                    .foregroundColor(.gray.opacity(0.4))
            }

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(color)
                    .frame(width: 65, height: height)

                Text("\(rank)")
                    .font(.system(size: 35, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 6)
            }
        }
    }

    // Leaderboard row
    @ViewBuilder
    func leaderboardRow(rank: Int, entry: LeaderboardEntry) -> some View {
        NavigationLink {
            ReusableProfileContent(
                user: entry.user,
                isMyProfile: entry.id == userUID,
                selectedGroupAdminID: adminID,
                activeGroupID: activeGroupID
            )
        } label: {
            HStack(spacing: 12) {

                // Rank number
                Text("\(rank)")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(accent.opacity(0.6))
                    .frame(width: 24, alignment: .leading)
                    .padding(.leading, 7)

                Rectangle()
                    .frame(width: 1, height: 40)
                    .foregroundColor(Color.gray.opacity(0.6))

                // Profile picture
                WebImage(url: entry.user.userProfileURL)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                    .padding(.leading, 7)

                // Username
                Text(entry.user.username)
                    .font(.system(size: 16, weight: .bold))

                Spacer()

                // Streak & likes (value → emoji order)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text("\(entry.streak)")
                        Text("🔥")
                    }
                    HStack(spacing: 4) {
                        Text("\(entry.likes)")   // ← correct per-group like total
                        Text("❤️")
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.trailing, 8)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(1), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Data loading
private extension LeaderboardView {

    /// Fetches all stats, then sorts by points
    @MainActor
    func loadLeaderboard() async {
        guard let gid = activeGroupID else { return }

        isLoading = true
        entries   = []

        let db = Firestore.firestore()

        // 1️⃣ Get member UID list
        var memberIDs: [String] = []
        do {
            let snap = try await db.collection("Groups")
                .document(gid)
                .getDocument()
            memberIDs = snap.get("members") as? [String] ?? []
        } catch {
            print("Group fetch error:", error)
        }
        guard !memberIDs.isEmpty else { isLoading = false; return }

        // 2️⃣ Build entries in parallel
        var temp: [LeaderboardEntry] = []
        await withTaskGroup(of: LeaderboardEntry?.self) { group in
            for uid in memberIDs {
                group.addTask {
                    do {
                        // User doc
                        let userDoc = try await db.collection("Users")
                            .document(uid)
                            .getDocument()
                        guard let user = try? userDoc.data(as: User.self) else { return nil }

                        // JoinedGroups stats
                        let joinedDoc = try await db.collection("Users")
                            .document(uid)
                            .collection("JoinedGroups")
                            .document(gid)
                            .getDocument()
                        let points = joinedDoc.get("points") as? Int ?? 0
                        let streak = joinedDoc.get("streak") as? Int ?? 0

                        // Likes = sum of likedIDs.count across this user's posts in this group
                        let postsSnap = try await db.collection("Posts")
                            .whereField("userUID", isEqualTo: uid)
                            .whereField("groupID", isEqualTo: gid)
                            .getDocuments()
                        let likes = postsSnap.documents.reduce(0) { sum, doc in
                            let arr = doc.get("likedIDs") as? [String] ?? []
                            return sum + arr.count
                        }

                        return LeaderboardEntry(id: uid,
                                                user: user,
                                                points: points,
                                                likes: likes,
                                                streak: streak)
                    } catch {
                        print("Fetch error for user \(uid):", error)
                        return nil
                    }
                }
            }

            for await e in group { if let e { temp.append(e) } }
        }

        // 3️⃣ Sort by points
        entries = temp.sorted { $0.points > $1.points }
        await MainActor.run { isLoading = false }   // loader turns off only when data is ready
    }
}

// MARK: - Safe subscript helper
private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
