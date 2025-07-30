import SwiftUI
import SDWebImageSwiftUI
import Firebase
import FirebaseFirestore

struct ReusablePostContent: View {
    var basedOnUID: Bool = false
    var uid: String = ""
    var activeGroupID: String? = nil
    
    @Binding var posts: [Post]
    @State private var isFetching: Bool = false
    @State private var paginationDoc: QueryDocumentSnapshot?
    @State private var streakCache: [String: Int] = [:]
    @State private var isStreaksLoaded: Bool = false

    
    let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    
    var body: some View {
        ScrollView {
            if isFetching {
                ProgressView()
                    .padding(.top, 30)
            }
            else {
                if posts.isEmpty {
                    Text("No Posts Found")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 30)
                }
                else if !isStreaksLoaded {
                    VStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    LazyVGrid(columns: columns, spacing: 15) {
                        Posts()
                    }
                    .padding(8)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
                }

            }
        }
        .task {
            guard basedOnUID else {
                isFetching = false
                isStreaksLoaded = true
                return
            }
            
            if posts.isEmpty {
                paginationDoc = nil
                await fetchPosts()
            }
        }




        .refreshable {
            guard basedOnUID else { return }
            posts = []
            paginationDoc = nil
            isStreaksLoaded = false
            await fetchPosts()
        }

        .onChange(of: posts) { _, newPosts in
            Task {
                streakCache = [:]
                isStreaksLoaded = false
                await preloadStreaks(for: newPosts)
                await MainActor.run {
                    isStreaksLoaded = true
                }
            }
        }

    }
    
    @ViewBuilder
    func Posts() -> some View {
        ForEach(posts) { post in
            NavigationLink {
                PostDetailView(
                    post: post,
                    onUpdate: { updatedPost in
                        if let index = posts.firstIndex(where: { $0.id == updatedPost.id }) {
                            posts[index].likedIDs = updatedPost.likedIDs
                        }
                    },
                    onDelete: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            posts.removeAll { $0.id == post.id }
                        }
                    }
                )
                .toolbar(.hidden, for: .tabBar)
            } label: {
                let streak = streakCache[post.userUID]
                ExploreCard(post: post, userStreak: streak)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .onAppear {
                if streakCache[post.userUID] == nil {
                    Task { await fetchStreak(for: post.userUID, in: post.groupID) }
                }
                if post.id == posts.last?.id && paginationDoc != nil {
                    Task { await fetchPosts() }
                }
            }

        }
    }


    func fetchStreak(for posterUID: String, in groupID: String?) async {
        guard
            !posterUID.isEmpty,
            let gid = groupID,
            !gid.isEmpty
        else { return }

        do {
            let snap = try await Firestore.firestore()
                .collection("Users")
                .document(posterUID)
                .collection("JoinedGroups")
                .document(gid)
                .getDocument()

            let streak = snap["streak"] as? Int ?? 0
            await MainActor.run { streakCache[posterUID] = streak }

        } catch {
        }
    }


    
    func fetchPosts() async {
        guard !isFetching else { return }
        await MainActor.run { isFetching = true }

        do {
            var query: Query!
            if let paginationDoc {
                query = Firestore.firestore().collection("Posts")
                    .order(by: "publishedDate", descending: true)
                    .start(afterDocument: paginationDoc)
                    .limit(to: 20)
            } else {
                query = Firestore.firestore().collection("Posts")
                    .order(by: "publishedDate", descending: true)
                    .limit(to: 20)
            }

            if basedOnUID {
                query = query.whereField("userUID", isEqualTo: uid)
            }

            let docs = try await query.getDocuments()
            let fetchedPosts = docs.documents.compactMap { doc in
                try? doc.data(as: Post.self)
            }

            await MainActor.run {
                posts.append(contentsOf: fetchedPosts)
                paginationDoc = docs.documents.last
            }

            await preloadStreaks(for: fetchedPosts)

            await MainActor.run {
                isFetching = false
                isStreaksLoaded = true
            }

        } catch {
            print(error.localizedDescription)
            await MainActor.run { isFetching = false }
        }
    }
    
    func preloadStreaks(for posts: [Post]) async {
        let uniqueUserIDs = Set(posts.map { $0.userUID })
        
        await withTaskGroup(of: Void.self) { group in
            for uid in uniqueUserIDs {
                group.addTask {
                    await fetchStreak(for: uid, in: activeGroupID)
                }
            }
        }
    }


}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct ExploreCard: View {
    let post: Post
    let userStreak: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                WebImage(url: post.imageURL)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.width)
                    .clipShape(RoundedCorner(radius: 6, corners: [.topLeft, .topRight]))
                    .clipped()
            }
            .frame(height: UIScreen.main.bounds.width / 2 - 22)

            Text(post.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .font(.system(size: 14, weight: .bold))

            HStack {
                WebImage(url: post.userProfileURL)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .clipped()
                    .frame(width: 18, height: 18)

                Text(post.userName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.trailing, -1.5)

                Spacer()

                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 11))
                    if let streak = userStreak {
                        Text("\(streak)")
                            .font(.system(size: 11))
                            .fontWeight(.semibold)
                    } else {
                        Text("–")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }

                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.4), lineWidth: 0.8)
        )
        .cornerRadius(6)
    }
}

