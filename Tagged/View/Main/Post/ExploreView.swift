import SwiftUI
import SDWebImageSwiftUI
import Firebase
import FirebaseFirestore

struct ExploreView: View {
    var activeGroupID: String?

    @State private var fetchedPosts: [Post] = []
    @State private var hasLoadedOnce = false
    
    @State private var currentTag: String = ""

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Scrollable content
                ScrollView {
                    VStack(spacing: 0) {
                        if fetchedPosts.isEmpty {
                            Text("No posts available.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.top, 40)
                        } else {
                            ReusablePostContent(activeGroupID: activeGroupID, posts: .constant(fetchedPosts))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .refreshable {
                    await fetchPosts()
                    await fetchCurrentTag()
                }
                
                // Divider line
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(height: 0.5)
                    .frame(maxWidth: .infinity)

                // Fixed tag bar at bottom
                VStack(alignment: .leading, spacing: 2) {
                    Text("This Week's Tag:")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .padding(.bottom, 6)

                    Text(currentTag.isEmpty ? "No tag set" : currentTag)
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 11)
                .padding(.bottom, 15)
                .background(Color.white)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            Task {
                await fetchPosts()
                await fetchCurrentTag()
            }
        }
        .onChange(of: activeGroupID) { _ in
            Task {
                await fetchPosts()
                await fetchCurrentTag()
            }
        }

    }

    func fetchCurrentTag() async {
        guard let groupID = activeGroupID else { return }

        do {
            let doc = try await Firestore.firestore().collection("Groups").document(groupID).getDocument()
            let tag = doc.data()?["currentTag"] as? String ?? ""
            await MainActor.run {
                self.currentTag = tag
            }
        } catch {
            print("❌ Failed to fetch currentTag:", error.localizedDescription)
        }
    }

    
    func fetchPosts() async {
        guard let groupID = activeGroupID else {
            await MainActor.run {
                fetchedPosts = []
            }
            return
        }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("Posts")
                .whereField("groupID", isEqualTo: groupID)
                .order(by: "publishedDate", descending: true)
                .limit(to: 50)
                .getDocuments()

            let posts = snapshot.documents.compactMap { try? $0.data(as: Post.self) }

            await MainActor.run {
                fetchedPosts = posts
            }

        } catch {
            print("❌ Firestore fetch error:", error)
            await MainActor.run {
                fetchedPosts = []
            }
        }
    }
}
