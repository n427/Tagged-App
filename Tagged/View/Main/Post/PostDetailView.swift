import SwiftUI
import SDWebImageSwiftUI
import Firebase
import FirebaseStorage
import FirebaseFirestore

struct PostDetailView: View {
    @State private var commentText: String = ""
    @State private var isFollowing = false
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
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                            .alignmentGuide(.firstTextBaseline) { d in d[.bottom] }
                            .padding(.trailing, 3)
                        
                        Text(post.userName)
                            .font(.system(size: 16, weight: .semibold))
                            .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
                        
                        HStack(spacing: 4) {
                            Text("🔥")
                                .font(.system(size: 15))
                            Text("3") // Replace with dynamic value if needed
                                .font(.caption)
                                .fontWeight(.semibold)
                                .font(.system(size: 15))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 4)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                isFollowing.toggle()
                            }
                        }) {
                            Image(systemName: isFollowing ? "checkmark.circle.fill" : "plus.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                        }
                        .padding(.trailing, 4)
                        
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                            .foregroundColor(.accentColor)
                            .padding(.top, -3)
                            .padding(.trailing, 4)
                        
                        if post.userUID == userUID{
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
                            HStack(alignment: .center) {
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

    func likePost() {
        guard let postID = post.id else { return }
        let postRef = Firestore.firestore().collection("Posts").document(postID)
        let userRef = Firestore.firestore().collection("Users").document(post.userUID)

        Firestore.firestore().runTransaction({ transaction, errorPointer in
            do {
                let postSnapshot = try transaction.getDocument(postRef)
                var likedIDs = postSnapshot.get("likedIDs") as? [String] ?? []

                let isLiked = likedIDs.contains(userUID)
                if isLiked {
                    likedIDs.removeAll { $0 == userUID }
                    transaction.updateData(["userPoints": FieldValue.increment(Int64(-1))], forDocument: userRef)
                } else {
                    likedIDs.append(userUID)
                    transaction.updateData(["userPoints": FieldValue.increment(Int64(1))], forDocument: userRef)
                }

                transaction.updateData(["likedIDs": likedIDs], forDocument: postRef)

            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }) { _, error in
            if let error = error {
                print("Transaction failed: \(error.localizedDescription)")
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
                .frame(width: 28, height: 28)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(comment.username)
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)

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
