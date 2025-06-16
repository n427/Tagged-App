import SwiftUI
import SDWebImageSwiftUI
import Firebase
import FirebaseFirestore

struct ReusablePostContent: View {
    var basedOnUID: Bool = false
    var uid: String = ""
    
    @Binding var posts: [Post]
    @State private var isFetching: Bool = false
    @State private var paginationDoc: QueryDocumentSnapshot?
    
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
                else {
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
            if posts.isEmpty {
                paginationDoc = nil  // reset pagination if needed
                await fetchPosts()
            }
        }

        .refreshable {
            guard basedOnUID else{return}
            posts = []
            paginationDoc = nil
            await fetchPosts()
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
                ExploreCard(post: post)
                    .contentShape(Rectangle()) // 👈 Ensures the entire card is tappable, no spillover
            }
            .buttonStyle(PlainButtonStyle()) // Prevents button effects
            .onAppear {
                if post.id == posts.last?.id && paginationDoc != nil {
                    Task { await fetchPosts() }
                }
            }
        }
    }


    
    func fetchPosts() async {
        guard !isFetching else { return } // optional: prevent double fetch
        await MainActor.run { isFetching = true } // ✅ show spinner

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
                isFetching = false
            }
        } catch {
            print(error.localizedDescription)
            await MainActor.run { isFetching = false }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                WebImage(url: post.imageURL)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.width) // enforce square
                    .clipShape(RoundedCorner(radius: 6, corners: [.topLeft, .topRight]))
                    .clipped()
            }
            .frame(height: UIScreen.main.bounds.width / 2 - 22) // pre-set height to match square grid cell

            // Caption
            Text(post.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .font(.system(size: 14, weight: .bold))

            HStack {
                WebImage(url: post.userProfileURL)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())

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
                    Text("3")
                        .font(.system(size: 11))
                        .fontWeight(.semibold)
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

