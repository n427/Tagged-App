import SwiftUI
import SDWebImageSwiftUI
import Firebase

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
            guard posts.isEmpty else{return}
            await fetchPosts()
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
            NavigationLink(
                destination: PostDetailView(
                    post: post,
                    onUpdate: { updatedPost in
                        if let index = posts.firstIndex(where: {post in
                            post.id == updatedPost.id
                        }){
                            posts[index].likedIDs = updatedPost.likedIDs
                        }
                    },
                    onDelete: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            posts.removeAll{post.id == $0.id}
                        }
                    }
                )
                .toolbar(.hidden, for: .tabBar)
            ) {
                ExploreCard(post: post)
            }
            .buttonStyle(PlainButtonStyle())
            .onAppear{
                if post.id == posts.last?.id && paginationDoc != nil {
                    Task{await fetchPosts()}
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


struct ExploreCard: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    WebImage(url: post.imageURL)
                        .resizable()
                        .scaledToFill()
                        .clipped() // 👈 ensure image doesn't overflow
                )
            
            .cornerRadius(6)

            // Caption - truncated
            Text(post.title)
                .font(.footnote)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)

            HStack {
                // PFP
                WebImage(url: post.userProfileURL)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())

                // Username - truncated
                Text(post.userName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.trailing, -1.5)

                Spacer()

                // Fire streak badge
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 11))
                    Text("3")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .font(.system(size: 11))
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
