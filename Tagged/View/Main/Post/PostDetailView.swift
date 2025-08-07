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
    @State private var showDoubleTapHeart = false
    @State private var newCommentID: String? = nil

    @State private var headerProfileURL: URL?
    @State private var headerName: String = ""
    
    var body: some View {
        ZStack {
            SwipeBackEnabler()
            
            if isFetching {
                ProgressView()
                    .padding(.top, 30)
            }
            else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 8) {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.accentColor)
                                .font(.system(size: 20, weight: .medium))
                                .padding(.trailing, 5)
                        }
                        
                        NavigationLink {
                            LazyProfileLoaderView(
                                userUID: post.userUID,
                                groupID: post.groupID ?? "",
                                currentUserUID: userUID
                            )
                        } label: {
                            WebImage(url: headerProfileURL)
                                .resizable()
                                .scaledToFill()
                                .clipShape(Circle())
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                        
                        Text(headerName)
                            .font(.system(size: 16, weight: .semibold))
                            .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
                        
                        HStack(spacing: 4) {
                            Text("🔥")
                                .font(.system(size: 15))
                            Text("\(currentStreak ?? 0)")
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
                    .onAppear {
                        Firestore.firestore()
                          .collection("Users")
                          .document(post.userUID)
                          .addSnapshotListener { snap, _ in
                            guard let data = snap?.data() else { return }
                            if let urlString = data["userProfileURL"] as? String {
                              headerProfileURL = URL(string: urlString)
                            }
                            headerName = data["name"] as? String ?? ""
                          }
                      }
                    ScrollView {
                        ZStack {
                            Color.gray.opacity(0.1)

                            WebImage(url: post.imageURL)
                                .resizable()
                                .scaledToFill()
                                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                                .clipped()
                                .onTapGesture(count: 2) {
                                    if !post.likedIDs.contains(userUID) {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        Task {
                                            await likePost()
                                        }

                                        withAnimation(.easeInOut(duration: 0.4)) {
                                            showDoubleTapHeart = true
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                            withAnimation(.easeOut(duration: 0.3)) {
                                                showDoubleTapHeart = false
                                            }
                                        }
                                    }
                                }

                            if showDoubleTapHeart {
                                Image(systemName: "heart.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(.red)
                                    .opacity(0.9)
                                    .scaleEffect(showDoubleTapHeart ? 1.0 : 0.5)
                                    .transition(.scale)
                            }
                        }
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                        .contentShape(Rectangle())

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                Text(post.title)
                                    .font(.system(size: 18, weight: .bold))
                                
                                Spacer()

                                HStack(spacing: 4) {
                                    Button(action: {
                                        Task {
                                            await likePost()
                                        }
                                    }) {
                                        ZStack {
                                            if post.likedIDs.contains(userUID) {
                                                Image(systemName: "heart.fill")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 25, height: 25)
                                                    .foregroundColor(.red)
                                            } else {
                                                Image(systemName: "heart")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 25, height: 25)
                                                    .foregroundColor(.clear)
                                                    .overlay(
                                                        Image(systemName: "heart")
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(width: 25, height: 25)
                                                            .foregroundColor(.red)

                                                    )
                                            }
                                        }
                                    }

                                    .frame(width: 30, height: 30)

                                    Text("\(post.likedIDs.count)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(minWidth: 25, alignment: .leading)
                                }
                                .padding(.trailing, -5)
                                .padding(.top, -5)
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
                                        .textFieldStyle(.automatic)
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
        .navigationBarBackButtonHidden(false)
        .navigationBarHidden(true)
        
        .onAppear {
            if docListener == nil {
                Task { await fetchStreak() }
                Task { await fetchAdminStatus() }
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
    
    func fetchAdminStatus() async {
        guard let gid = post.groupID, !gid.isEmpty else { return }

        do {
            let joinedSnap = try await Firestore.firestore()
                .collection("Users")
                .document(userUID)
                .collection("JoinedGroups")
                .document(gid)
                .getDocument()

            let adminID = joinedSnap.get("groupMeta.adminID") as? String
                ?? joinedSnap.get("adminID") as? String
                ?? ""

            await MainActor.run { isAdmin = (adminID == userUID) }

        } catch {
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
                .document(post.userUID)
                .collection("JoinedGroups")
                .document(groupID)
                .getDocument()

            let streak = snap["streak"] as? Int ?? 0
            await MainActor.run {
                currentStreak = streak
            }

        } catch {
        }
    }
    
    func likePost() async {
        guard
            let postID  = post.id,
            let groupID = post.groupID
        else { return }

        let db        = Firestore.firestore()
        let postRef   = db.collection("Posts").document(postID)
        let userRef   = db.collection("Users").document(post.userUID)
        let joinedRef = userRef
            .collection("JoinedGroups")
            .document(groupID)

        db.runTransaction({ txn, errPtr -> Any? in
            do {
                let postSnap = try txn.getDocument(postRef)
                var likedIDs = postSnap.get("likedIDs") as? [String] ?? []

                let alreadyLiked = likedIDs.contains(userUID)
                let delta: Int64 = alreadyLiked ? -1 : 1

                if alreadyLiked {
                    likedIDs.removeAll { $0 == userUID }
                } else {
                    likedIDs.append(userUID)
                }
                txn.updateData(["likedIDs": likedIDs], forDocument: postRef)

                txn.updateData([
                    "userLikeCount": FieldValue.increment(delta)
                ], forDocument: userRef)

                txn.updateData([
                    "points": FieldValue.increment(delta)
                ], forDocument: joinedRef)

            } catch {
                errPtr?.pointee = error as NSError
            }
            
            return nil
            }) { _, error in
            
        }
        
        if !post.likedIDs.contains(userUID) {
            do {
                let userSnap = try await Firestore.firestore()
                    .collection("Users")
                    .document(userUID)
                    .getDocument()

                let username = userSnap["username"] as? String ?? "Someone"

                try await Firestore.firestore()
                    .collection("Posts")
                    .document(postID)
                    .collection("likes")
                    .document(userUID)
                    .setData([
                        "username": username
                    ])
            } catch {
            }
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
                    onDelete()
                    dismiss()
                }
            }catch {
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
        await MainActor.run {
            newCommentID = newComment.id
            commentText = ""
        }
    }

    func listenToComments(for postID: String) {
        Firestore.firestore()
            .collection("Posts")
            .document(postID)
            .collection("comments")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }

                comments = documents.compactMap { doc in
                    do {
                        return try doc.data(as: Comment.self)
                    } catch {
                        return nil
                    }
                }
            }
    }

    
    func commentRow(comment: Comment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            NavigationLink {
                LazyProfileLoaderView(
                    userUID: comment.userUID,
                    groupID: post.groupID ?? "",
                    currentUserUID: userUID
                )
            } label: {
                WebImage(url: comment.userProfileURL)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
            }
            
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
        .id(comment.id ?? UUID().uuidString)
        .opacity(comment.id == newCommentID ? 0 : 1)
        .animation(.easeOut(duration: 0.3), value: newCommentID)
        .onAppear {
            if comment.id == newCommentID {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        newCommentID = nil
                    }
                }
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
