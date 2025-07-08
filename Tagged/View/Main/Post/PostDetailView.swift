import SwiftUI
import SDWebImageSwiftUI
import Firebase
import FirebaseStorage
import FirebaseFirestore

struct PostDetailView: View {
    @State private var commentText: String = ""
    @State private var isFollowing = false
    @State private var currentStreak: Int? = nil
    @State private var isAdmin = false

    @Environment(\.dismiss) var dismiss

    @State var isFetching: Bool = false
    
    @AppStorage("user_UID") private var userUID: String = ""
    @AppStorage("user_profile_url") private var profileURL: URL?
    @State private var docListener: ListenerRegistration?
    
    @State var post: Post
    var onUpdate: (Post) -> ()
    var onDelete: () -> ()
    @State private var comments: [Comment] = []
    
    var body: some View {
        ZStack {
            SwipeBackEnabler()
            
            if isFetching {
                ProgressView()
                    .padding(.top, 30)
            }
            else {
                VStack(alignment: .leading, spacing: 0) {
                    // Post Header
                    // Post Header - white bar ABOVE the image
                    HStack(alignment: .center, spacing: 8) {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.accentColor)
                                .font(.system(size: 20, weight: .medium))
                                .padding(.trailing, 5)
                        }
                        
                        WebImage(url: post.userProfileURL)
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                            .clipped()
                            .frame(width: 30, height: 30)
                            .alignmentGuide(.firstTextBaseline) { d in d[.bottom] }
                            .padding(.trailing, 3)
                        
                        Text(post.userName)
                            .font(.system(size: 16, weight: .semibold))
                            .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
                        
                        HStack(spacing: 4) {
                            Text("🔥")
                                .font(.system(size: 15))
                            Text("\(currentStreak ?? 0)") // Replace with dynamic value if needed
                                .font(.caption)
                                .fontWeight(.semibold)
                                .font(.system(size: 15))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 4)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        Spacer()
                        
                        if post.userUID == userUID || isAdmin {
                            Menu {
                                Button("Delete Post", role: .destructive, action: deletePost)
                            } label: {
                            Image(systemName: "trash")
                                    .font(.system(size: 18))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 15)
                    .background(Color.white)
                    
                    ScrollView {
                        ZStack {
                            Color.gray.opacity(0.1)
                            
                            WebImage(url: post.imageURL)
                                .resizable()
                                .scaledToFill()
                                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                                .clipped()
                        }
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                        .allowsHitTesting(false) // ✅ prevents intercepting taps
                        
                        
                        // User + Caption
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                Text(post.title)
                                    .font(.system(size: 18, weight: .bold))
                                
                                Spacer()

                                HStack(spacing: 4) {
                                    Button(action: likePost) {
                                        Image(systemName: post.likedIDs.contains(userUID) ? "heart.fill" : "heart")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 25, height: 25)
                                            .foregroundColor(post.likedIDs.contains(userUID) ? .red : .black)
                                    }
                                    .frame(width: 30, height: 30) // ensures consistent button width even if tapped

                                    Text("\(post.likedIDs.count)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(minWidth: 25, alignment: .leading) // optional: prevents shifting when numbers grow
                                }
                                .padding(.trailing, -5)
                            }
                            .padding(.vertical, 5)

                            Text(post.text)
                                .font(.system(size: 14))
                                .foregroundColor(.black)

                            Text(post.publishedDate.formatted(date: .numeric, time: .shortened))
                                .font(.system(size: 12))
                                .foregroundColor(.gray.opacity(0.7))
                                .padding(.top, 4)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)

                        
                        Divider()
                        
                        // Comments Label
                        HStack {
                            Text("Comments")
                                .font(.system(size: 18, weight: .semibold))
                            Spacer()
                        }
                        .padding(.leading, 15)
                        .padding(.top, 10)
                        .padding(.bottom, 5)
                        
                        HStack(alignment: .center, spacing: 8) {
                            
                            WebImage(url: profileURL)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())
                            
                            ZStack(alignment: .bottomTrailing) {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white)
                                
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                
                                HStack(alignment: .bottom, spacing: 6) {
                                    TextField("Write a comment...", text: $commentText, axis: .vertical)
                                        .font(.system(size: 14))
                                        .lineLimit(5)
                                        .textFieldStyle(.automatic) // <- important
                                        .padding(.vertical, 10)
                                        .padding(.leading, 12)
                                    
                                    Button(action: {
                                        let trimmedComment = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
                                        guard !trimmedComment.isEmpty else { return }
                                        Task {
                                            do {
                                                let userDoc = try await Firestore.firestore()
                                                    .collection("Users")
                                                    .document(userUID)
                                                    .getDocument(as: User.self)
                                                try await postComment(for: post.id ?? "", text: commentText, user: userDoc)
                                                commentText = ""
                                            } catch {
                                                print("Failed to post comment:", error)
                                            }
                                        }
                                    }) {
                                        Image(systemName: "paperplane.fill")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(Color.accentColor)
                                    }
                                    .padding(.trailing, 12)
                                    .padding(.bottom, 8)
                                }
                                .padding(.vertical, 2)
                            }
                            .padding(.leading, 5)
                        }
                        .padding(.horizontal)
                        .padding(.top, 7)
                        .padding(.bottom, 10)
                        
                        
                        // Comment List
                        VStack(spacing: 30) {
                            ForEach(comments) { comment in
                                commentRow(comment: comment)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }

        }
        .navigationBarBackButtonHidden(false) // allow default gesture
        .navigationBarHidden(true) // hide only the visual bar
        
        .onAppear {
            if docListener == nil {
                Task { await fetchStreak() }
                Task { await fetchAdminStatus() }      // ← NEW
                guard let postID = post.id else { return }

                docListener = Firestore.firestore()
                    .collection("Posts")
                    .document(postID)
                    .addSnapshotListener { snapshot, error in
                        if let snapshot, snapshot.exists {
                            if let updatedPost = try? snapshot.data(as: Post.self) {
                                post = updatedPost
                                onUpdate(updatedPost)
                            }
                        } else {
                            onDelete()
                        }
                    }

                // ✅ Start listening for comments too!
                listenToComments(for: postID)
            }
        }

        .refreshable {
            
        }
        .onDisappear {
            if let docListener {
                docListener.remove()
                self.docListener = nil
            }
        }
    }
    
    /// Checks if `user_UID` matches this group’s adminID.
    func fetchAdminStatus() async {
        guard let gid = post.groupID, !gid.isEmpty else { return }

        do {
            // 1️⃣  OPTION A — quickest (your JoinedGroups sub-doc)
            let joinedSnap = try await Firestore.firestore()
                .collection("Users")
                .document(userUID)
                .collection("JoinedGroups")
                .document(gid)
                .getDocument()

            // If you store `adminID` in the sub-doc’s `groupMeta`:
            let adminID = joinedSnap.get("groupMeta.adminID") as? String
                ?? joinedSnap.get("adminID") as? String
                ?? ""                                // fallback

            await MainActor.run { isAdmin = (adminID == userUID) }

        } catch {
            print("❌ fetchAdminStatus:", error.localizedDescription)
        }
    }

    
    func fetchStreak() async {
        guard
            let groupID = post.groupID,
            !groupID.isEmpty
        else { return }

        do {
            let snap = try await Firestore.firestore()
                .collection("Users")
                .document(post.userUID) // ← fetch the *poster’s* joined group doc
                .collection("JoinedGroups")
                .document(groupID)
                .getDocument()

            let streak = snap["streak"] as? Int ?? 0
            await MainActor.run {
                currentStreak = streak
            }

        } catch {
            print("❌ fetchStreak error:", error.localizedDescription)
        }
    }
    
    func likePost() {
        guard
            let postID  = post.id,
            let groupID = post.groupID         // every post stores its server
        else { return }

        let db        = Firestore.firestore()
        let postRef   = db.collection("Posts").document(postID)
        let userRef   = db.collection("Users").document(post.userUID)
        let joinedRef = userRef
            .collection("JoinedGroups")
            .document(groupID)

        db.runTransaction({ txn, errPtr -> Any? in
            do {
                // ── 1. read current likedIDs ───────────────────────────────
                let postSnap = try txn.getDocument(postRef)
                var likedIDs = postSnap.get("likedIDs") as? [String] ?? []

                let alreadyLiked = likedIDs.contains(userUID)
                let delta: Int64 = alreadyLiked ? -1 : 1

                // ── 2. mutate likedIDs array ──────────────────────────────
                if alreadyLiked {
                    likedIDs.removeAll { $0 == userUID }
                } else {
                    likedIDs.append(userUID)
                }
                txn.updateData(["likedIDs": likedIDs], forDocument: postRef)

                // ── 3. global like counter on poster’s user doc ───────────
                txn.updateData([
                    "userLikeCount": FieldValue.increment(delta)
                ], forDocument: userRef)

                // ── 4. per-server points on JoinedGroups ─────────────────
                txn.updateData([
                    "points": FieldValue.increment(delta)
                ], forDocument: joinedRef)

            } catch {
                errPtr?.pointee = error as NSError
            }
            return nil
        }) { _, error in
            if let error { print("🔥 likePost txn failed:", error.localizedDescription) }
        }
    }



    func deletePost() {
        Task {
            do {
                if post.imageReferenceID != "" {
                    try await Storage.storage().reference().child("Post_Images").child(post.imageReferenceID).delete()
                }
                guard let postID = post.id else{return}
                try await Firestore.firestore().collection("Posts").document(postID).delete()
                await MainActor.run {
                    onDelete()            // Notify parent
                    dismiss()            // 👈 Auto-dismiss the view
                }
            }catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func postComment(for postID: String, text: String, user: User) async throws {
        let commentRef = Firestore.firestore()
            .collection("Posts")
            .document(postID)
            .collection("comments")
            .document()

        let newComment = Comment(
            id: commentRef.documentID,
            text: text,
            userUID: user.userUID,
            username: user.username,
            userProfileURL: user.userProfileURL,
            timestamp: Date(),
            likedBy: []
        )

        try commentRef.setData(from: newComment)
    }

    func listenToComments(for postID: String) {
        Firestore.firestore()
            .collection("Posts")
            .document(postID)
            .collection("comments")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }

                comments = documents.compactMap { doc in
                    do {
                        return try doc.data(as: Comment.self)
                    } catch {
                        print("❌ Failed to decode comment:", doc.data())
                        print("Error:", error)
                        return nil
                    }
                }
            }
    }

    
    func commentRow(comment: Comment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            WebImage(url: comment.userProfileURL)
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(comment.username)
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                    .fontWeight(.semibold)

                Text(comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                
                    .padding(.top, 4)

                Text(comment.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }

            Spacer()

            VStack(spacing: 4) {
                Button {
                    toggleLikeOnComment(comment)
                } label: {
                    Image(systemName: (comment.likedBy ?? []).contains(userUID) ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundColor((comment.likedBy ?? []).contains(userUID) ? .red : .gray)
                }

                Text("\((comment.likedBy ?? []).count)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    func toggleLikeOnComment(_ comment: Comment) {
        guard let commentID = comment.id, let postID = post.id else { return }

        let ref = Firestore.firestore()
            .collection("Posts")
            .document(postID)
            .collection("comments")
            .document(commentID)

        let alreadyLiked = (comment.likedBy ?? []).contains(userUID)

        ref.updateData([
            "likedBy": alreadyLiked ?
                FieldValue.arrayRemove([userUID]) :
                FieldValue.arrayUnion([userUID])
        ])
    }

}
