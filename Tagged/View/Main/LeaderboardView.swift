import SwiftUI
import SDWebImageSwiftUI
import FirebaseFirestore

struct LeaderboardEntry: Identifiable {
    let id: String
    let user: User
    let points: Int
    let likes: Int
    let streak: Int
}

struct LeaderboardView: View {

    @ObservedObject var groupsVM: GroupsViewModel
    @AppStorage("user_UID") private var userUID: String = ""

    private var activeGroupID: String? { groupsVM.activeGroupID }
    private var adminID: String? {
        groupsVM.myJoinedGroups.first { $0.groupID == activeGroupID }?.groupMeta.adminID
    }

    @State private var entries:   [LeaderboardEntry] = []
    @State private var isLoading: Bool               = true

    private let accent = Color.accentColor

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                
                if isLoading {
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
                    .padding(.top, -55)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                }
                
                if !isLoading {
                    VStack(spacing: 24) {
                        
                        if !entries.isEmpty {
                            podiumSection
                        }

                        Divider()
                            .padding(.horizontal, 25)
                            .padding(.bottom, -20)
                        
                        ScrollView {
                            VStack(spacing: 20) {
                                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                    leaderboardRow(rank: index + 1, entry: entry)
                                }
                            }
                            .padding(.horizontal, 25)
                            .padding(.bottom, 40)
                            .padding(.top, 1)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isLoading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task { await loadLeaderboard() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .onAppear { Task { await loadLeaderboard() } }
        .onChange(of: groupsVM.activeGroupID) {
            Task { await loadLeaderboard() }
        }

    }
}

private extension LeaderboardView {

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

    var podiumSection: some View {
        let top3 = Array(entries.prefix(3))
        return HStack(alignment: .bottom, spacing: 24) {
            podiumColumn(rank: 2, entry: top3[safe: 1], height: 100, color: accent.opacity(0.6))
            podiumColumn(rank: 1, entry: top3[safe: 0], height: 140, color: accent)
            podiumColumn(rank: 3, entry: top3[safe: 2], height: 80,  color: accent.opacity(0.6))
        }
        .padding(.top, 20)
    }

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
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [color.opacity(0.7), color.opacity(0.4)]),
                        startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 65, height: height)

                Text("\(rank)")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.top, 6)
            }

        }
    }

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

                Text("\(rank)")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(accent.opacity(0.6))
                    .frame(width: 24, alignment: .leading)
                    .padding(.leading, 7)

                Rectangle()
                    .frame(width: 1, height: 40)
                    .foregroundColor(Color.accentColor.opacity(0.6))

                WebImage(url: entry.user.userProfileURL)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                    .padding(.leading, 7)

                Text(entry.user.username)
                    .font(.system(size: 16, weight: .bold))

                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text("\(entry.streak)")
                        Text("🔥")
                    }
                    HStack(spacing: 4) {
                        Text("\(entry.likes)")
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
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 0.5)
            )
        }
    }
}

private extension LeaderboardView {

    @MainActor
    func loadLeaderboard() async {
        guard let gid = activeGroupID else { return }

        isLoading = true
        entries   = []

        let db = Firestore.firestore()

        var memberIDs: [String] = []
        do {
            let snap = try await db.collection("Groups")
                .document(gid)
                .getDocument()
            memberIDs = snap.get("members") as? [String] ?? []
        } catch {
        }
        guard !memberIDs.isEmpty else { isLoading = false; return }

        var temp: [LeaderboardEntry] = []
        await withTaskGroup(of: LeaderboardEntry?.self) { group in
            for uid in memberIDs {
                group.addTask {
                    do {
                        let userDoc = try await db.collection("Users")
                            .document(uid)
                            .getDocument()
                        guard let user = try? userDoc.data(as: User.self) else { return nil }

                        let joinedDoc = try await db.collection("Users")
                            .document(uid)
                            .collection("JoinedGroups")
                            .document(gid)
                            .getDocument()
                        let points = joinedDoc.get("points") as? Int ?? 0
                        let streak = joinedDoc.get("streak") as? Int ?? 0

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
                        return nil
                    }
                }
            }

            for await e in group { if let e { temp.append(e) } }
        }

        entries = temp.sorted { $0.points > $1.points }
        await MainActor.run { isLoading = false }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
