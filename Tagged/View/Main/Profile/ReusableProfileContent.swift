import SwiftUI
import SDWebImageSwiftUI
import Firebase
import FirebaseFirestore

// MARK: - ReusableProfileContent

struct ReusableProfileContent: View {
    var user: User
    var isMyProfile: Bool
    var logOutAction: (() -> Void)? = nil
    var deleteAccountAction: (() -> Void)? = nil

    @State private var showSettings = false
    @State private var fetchedPosts: [Post] = []
    @State private var isFetching: Bool = false
    @State private var paginationDoc: QueryDocumentSnapshot?

    // 3-column grid layout
    let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {

                    // MARK: - Profile Header

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
                                .foregroundColor(.primary)
                                .font(.headline)

                            HStack(spacing: 35) {
                                statView("\(fetchedPosts.count)", "posts")
                                statView("80", "likes")
                                statView("300", "points")
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    HStack(alignment: .top) {
                        Text("🔥 4-week")
                            .foregroundColor(.accentColor)
                            .fontWeight(.semibold)
                        Text(" streak")
                            .foregroundColor(.primary)
                            .fontWeight(.semibold)
                            .padding(.horizontal, -6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // MARK: - Bio

                    HStack(spacing: 0) {
                        Text(user.userBio)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, -10)

                    // MARK: - Buttons

                    if isMyProfile {
                        HStack(spacing: 16) {
                            NavigationLink(destination: EditProfileView()) {
                                Text("Edit Profile")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Color.accentColor)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 7)
                                            .stroke(Color.accentColor, lineWidth: 1)
                                    )
                            }
                            profileButton("Settings") {
                                showSettings.toggle()
                            }
                            .confirmationDialog("Settings", isPresented: $showSettings) {
                                Button(role: .none) {
                                    logOutAction?()
                                } label: {
                                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                                Button(role: .destructive) {
                                    deleteAccountAction?()
                                } label: {
                                    Label("Delete Account", systemImage: "trash")
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 5)
                    } else {
                        HStack(spacing: 16) {
                            profileButton("Follow") {}
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 5)
                    }

                    Divider()
                        .padding(.horizontal)
                        .padding(.bottom, 5)

                    // MARK: - Grid of Posts

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
                                ZStack {
                                    NavigationLink {
                                        PostDetailView(
                                            post: post,
                                            onUpdate: { updatedPost in
                                                if let index = fetchedPosts.firstIndex(where: { $0.id == updatedPost.id }) {
                                                    fetchedPosts[index].likedIDs = updatedPost.likedIDs
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
                                            .frame(width: imageSize(), height: imageSize())
                                            .clipped()
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .contentShape(Rectangle()) // Makes the entire tile tappable
                                .id(post.id) // Prevents index mismatch on reuse
                                .onAppear {
                                    if post.id == fetchedPosts.last?.id && paginationDoc != nil {
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
            .task {
                guard fetchedPosts.isEmpty else { return }
                await fetchPosts()
            }
            .refreshable {
                fetchedPosts = []
                paginationDoc = nil
                await fetchPosts()
            }
        }
        .padding(.top, -15)
    }

    // MARK: - Helpers

    func imageSize() -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let totalSpacing: CGFloat = 25 * 2
        let totalPadding: CGFloat = 4 * 2
        return (screenWidth - totalSpacing - totalPadding) / 3
    }

    func statView(_ number: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(number).bold()
            Text(label)
                .font(.footnote)
        }
    }

    func profileButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.accentColor, lineWidth: 1)
                )
        }
    }

    // MARK: - Firestore Pagination

    func fetchPosts() async {
        await MainActor.run { isFetching = true }

        do {
            var query: Query = Firestore.firestore()
                .collection("Posts")
                .order(by: "publishedDate", descending: true)
                .limit(to: 20)

            if let lastDoc = paginationDoc {
                query = query.start(afterDocument: lastDoc)
            }

            query = query.whereField("userUID", isEqualTo: user.userUID)

            let docs = try await query.getDocuments()
            let newPosts = docs.documents.compactMap { try? $0.data(as: Post.self) }

            await MainActor.run {
                fetchedPosts.append(contentsOf: newPosts)
                paginationDoc = docs.documents.last
                isFetching = false
            }
        } catch {
            print("Error fetching posts: \(error.localizedDescription)")
            await MainActor.run { isFetching = false }
        }
    }
}
