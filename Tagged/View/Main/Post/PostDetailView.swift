import SwiftUI
import SDWebImageSwiftUI
import Firebase
import FirebaseStorage

struct PostDetailView: View {
    @State private var commentText: String = ""
    @State private var isFollowing = false
    @Environment(\.dismiss) var dismiss

    @State var isFetching: Bool = false
    
    @AppStorage("user_UID") private var userUID: String = ""
    @State private var docListener: ListenerRegistration?
    
    @State var post: Post
    var onUpdate: (Post) -> ()
    var onDelete: () -> ()
    
    var body: some View {
        ScrollView {
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
                    .padding(.vertical, 10)
                    .background(Color.white)
                    
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
                    VStack(alignment: .leading, spacing: 4) {
                        
                        HStack(alignment: .center) {
                            Text(post.title)
                                .font(.system(size: 18, weight: .semibold))
                            
                            Spacer()
                            
                            Button(action: likePost) {
                                Image(systemName: post.likedIDs.contains(userUID) ? "heart.fill" : "heart")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 25, height: 25) // fixed size
                                    .foregroundColor(post.likedIDs.contains(userUID) ? .red : .black)
                            }
                            
                            Text("\(post.likedIDs.count)")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.vertical, 5)
                        
                        Text(post.text)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Text(post.publishedDate.formatted(date: .numeric, time: .shortened))
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.7))
                            .padding(.top, 4)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    
                    Divider()
                    
                    // Comments Label
                    Text("Comments")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal)
                        .padding(.top, 15)
                        .padding(.bottom, 10)
                    
                    HStack(alignment: .center, spacing: 8) {
                        
                        Image(systemName: "person.crop.circle.fill")
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
                                    .padding(.vertical, 10)
                                    .padding(.leading, 12)
                                
                                Button(action: {
                                    commentText = ""
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
                        ForEach(sampleComments) { comment in
                            commentRow(comment: comment)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal)
                }
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }

        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .onAppear {
            if docListener == nil {
                guard let postID = post.id else{return}
                docListener = Firestore.firestore().collection("Posts").document(postID).addSnapshotListener({snapshot,
                        error in
                    if let snapshot {
                        if snapshot.exists{
                            if let updatedPost = try? snapshot.data(as: Post.self) {
                                post = updatedPost
                                onUpdate(updatedPost)
                            }
                        }
                        else {
                            onDelete()
                        }
                    }
                })
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
        Task {
            guard let postID = post.id else {return}
            if post.likedIDs.contains(userUID) {
                try await Firestore.firestore().collection("Posts").document(postID).updateData([
                    "likedIDs": FieldValue.arrayRemove([userUID])
                ])
            }else {
                try await Firestore.firestore().collection("Posts").document(postID).updateData([
                    "likedIDs": FieldValue.arrayUnion([userUID])
                ])
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
    
    func commentRow(comment: Comment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.username)
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor.opacity(0.5))

                    Text(comment.text)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                    
                        .padding(.top, 4)

                    Text(comment.date)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                }
                .padding(.leading, 5)

                Spacer()

                VStack(spacing: 4) {
                    Image(systemName: "heart")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    Text("\(comment.likes)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct Comment: Identifiable {
    let id = UUID()
    let username: String
    let text: String
    let date: String
    let likes: Int
}

let sampleComments: [Comment] = [
    Comment(username: "venus", text: "early 2024 & a couple weeks ago ♡", date: "2 days ago", likes: 7),
    Comment(username: "Michelle Solano", text: "Omgg i loved your pink hair", date: "3 days ago", likes: 1),
    Comment(username: "Eli", text: "I think I have non I only have grow older 🤣", date: "2 days ago", likes: 7),
    Comment(username: "Obnauseous", text: "glow up by turning the lights off? 😭", date: "2 days ago", likes: 4)
]
