import SwiftUI
import SDWebImageSwiftUI
import Firebase
import FirebaseFirestore

struct ExploreView: View {
    var activeGroupID: String?
    @State private var tagListener: ListenerRegistration?

    @State private var fetchedPosts: [Post] = []
    @State private var hasLoadedOnce = false

    @State private var currentTag: String = ""
    @ObservedObject var groupsVM: GroupsViewModel
    @State private var isLoadingPosts = true
    

    var body: some View {
        SwiftUI.Group {
            if let groupID = activeGroupID, !groupID.isEmpty {
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        ScrollView {
                            ZStack {
                                if isLoadingPosts {
                                    VStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(Color.accentColor.opacity(0.05))
                                                .frame(width: 40, height: 40)

                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: Color.accentColor))
                                                .scaleEffect(1)
                                        }
                                        .padding(.top, 60)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: geo.size.height * 0.75)
                                    .transition(.opacity)
                                }

                                else if fetchedPosts.isEmpty {
                                    VStack {
                                        Spacer()
                                        Text("No posts yet!")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                            .padding(.top, 60)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, minHeight: geo.size.height * 0.75)
                                    .transition(.opacity)
                                }

                                else {
                                    ReusablePostContent(activeGroupID: activeGroupID, posts: .constant(fetchedPosts))
                                        .transition(.opacity)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .animation(.easeInOut(duration: 0.25), value: isLoadingPosts)
                        }

                        .refreshable {
                            let groupID = groupsVM.activeGroupID ?? ""
                            let didRotate = await groupsVM.checkAndUpdateTag(for: groupID)
                            if didRotate {
                                try? await Task.sleep(nanoseconds: 500_000_000)
                            }
                            listenToCurrentTag()
                            await fetchPosts()
                            await groupsVM.fetchStreaks()
                        }

                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(height: 0.5)
                            .frame(maxWidth: .infinity)

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
                    guard !hasLoadedOnce else { return }
                    hasLoadedOnce = true

                    Task {
                        let groupID = groupsVM.activeGroupID ?? ""
                        let didUpdate = await groupsVM.checkAndUpdateTag(for: groupID)
                        if didUpdate {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                        }
                        listenToCurrentTag()
                        await fetchPosts()
                        await groupsVM.fetchStreaks()
                    }
                }

                .onChange(of: activeGroupID) {
                    Task {
                        await fetchPosts()
                        listenToCurrentTag()
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    func listenToCurrentTag() {
        guard let groupID = activeGroupID else { return }

        tagListener?.remove()

        tagListener = Firestore.firestore()
            .collection("Groups")
            .document(groupID)
            .addSnapshotListener { snapshot, error in
                if error != nil {
                    return
                }

                guard let data = snapshot?.data() else {
                    return
                }

                let tag = (data["currentTag"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "No Tag Set"
                self.currentTag = tag
            }
    }

    func fetchPosts() async {
        guard let groupID = activeGroupID else {
            await MainActor.run {
                fetchedPosts = []
                isLoadingPosts = false
            }
            return
        }

        do {
            let pst = TimeZone(identifier: "America/Los_Angeles")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = pst

            let now = Date()
            let weekday = calendar.component(.weekday, from: now)
            let daysSinceMonday = (weekday + 5) % 7

            let mondayStartPST = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -daysSinceMonday, to: now)!)

            let snapshot = try await Firestore.firestore()
                .collection("Posts")
                .whereField("groupID", isEqualTo: groupID)
                .whereField("publishedDate", isGreaterThanOrEqualTo: Timestamp(date: mondayStartPST))

                .order(by: "publishedDate", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            let posts = snapshot.documents.compactMap { try? $0.data(as: Post.self) }

            await MainActor.run {
                fetchedPosts = posts
                isLoadingPosts = false
            }

        } catch {
            await MainActor.run {
                fetchedPosts = []
                isLoadingPosts = false
            }
        }
    }

}
