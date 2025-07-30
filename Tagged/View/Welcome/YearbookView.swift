import SwiftUI
import Firebase
import SDWebImageSwiftUI

struct YearbookView: View {
    @AppStorage("user_UID") private var userUID: String = ""
    var activeGroupID: String?

    @State private var postsByWeek: [Date: [Post]] = [:]
    @State private var isLoading = true

    @State private var isInitialLoad = true

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        ScrollView {
            Color.clear
                    .frame(height: 10)
            if isInitialLoad && isLoading {
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.accentColor.opacity(0.05))
                            .frame(width: 40, height: 40)

                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.accentColor))
                            .scaleEffect(1)
                    }
                    .padding(.top, -20)
                }
                .frame(maxWidth: .infinity, minHeight: UIScreen.main.bounds.height * 0.75)
                .transition(.opacity)
            }
            else if postsByWeek.isEmpty {
                VStack {
                    Spacer()

                    Text("No posts yet!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.top, -50)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: UIScreen.main.bounds.height * 0.75)
            }
            else {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(sortedWeekKeys, id: \.self) { weekStart in
                        let posts = postsByWeek[weekStart] ?? []
                        let caption = posts.sorted(by: { $0.publishedDate < $1.publishedDate }).first?.tag ?? "No Caption"

                        VStack(alignment: .leading, spacing: 10) {
                            Text("📆 Week of \(formatted(weekStart))")
                                .font(.title3.bold())
                                .padding(.horizontal)
                                .foregroundColor(.accentColor).opacity(1)

                            Text("🏷️ Tag: \(caption)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            LazyVGrid(columns: columns, spacing: 4) {
                                ForEach(posts) { post in
                                    NavigationLink {
                                        PostDetailView(
                                            post: post,
                                            onUpdate: { updated in
                                                if let i = postsByWeek[weekStart]?.firstIndex(where: { $0.id == updated.id }) {
                                                    postsByWeek[weekStart]?[i].likedIDs = updated.likedIDs
                                                }
                                            },
                                            onDelete: {
                                                postsByWeek[weekStart]?.removeAll { $0.id == post.id }
                                            }
                                        )
                                    } label: {
                                        WebImage(url: post.imageURL)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: tileSize, height: tileSize)
                                            .clipped()
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .frame(width: tileSize, height: tileSize)
                                }
                            }
                            .padding(.horizontal, 15)
                        }
                    }
                }
                .padding(.top)
                .padding(.bottom, 15)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchYearbookPosts(isInitial: true)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: isLoading)
        .refreshable {
            await fetchYearbookPosts(isInitial: false)
        }
        .onAppear {
            UIRefreshControl.appearance().tintColor = UIColor(named: "Loading")
        }


    }

    private var sortedWeekKeys: [Date] {
        postsByWeek.keys.sorted(by: >)
    }

    private var tileSize: CGFloat {
        let screen = UIScreen.main.bounds.width
        let margins: CGFloat = 25 * 2
        let spacing: CGFloat = 4 * 2
        return (screen - margins - spacing) / 3
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }

    private func startOfTaggedWeek(for date: Date) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        guard let weekStart = calendar.date(from: components) else { return date }

        return calendar.date(byAdding: .day, value: 0, to: weekStart) ?? weekStart
    }

    private func fetchYearbookPosts(isInitial: Bool) async {
        guard let groupID = activeGroupID, !groupID.isEmpty else { return }

        if isInitial {
            await MainActor.run {
                isLoading = true
                isInitialLoad = true
            }
        }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("Posts")
                .whereField("groupID", isEqualTo: groupID)
                .order(by: "publishedDate", descending: true)
                .getDocuments()

            var grouped: [Date: [Post]] = [:]

            for doc in snapshot.documents {
                if let post = try? doc.data(as: Post.self) {
                    let weekStart = startOfTaggedWeek(for: post.publishedDate)
                    grouped[weekStart, default: []].append(post)
                }
            }

            await MainActor.run {
                postsByWeek = grouped
                isLoading = false
                isInitialLoad = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                isInitialLoad = false
            }
        }
    }

}
