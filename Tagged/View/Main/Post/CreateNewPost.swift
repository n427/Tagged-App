import SwiftUI
import PhotosUI
import Firebase
import FirebaseStorage
import FirebaseFirestore

struct CreateNewPost: View {
    @ObservedObject var groupsVM: GroupsViewModel
    
    var onPost: (Post) -> ()

    @FocusState private var focusedField: Field?
    private enum Field { case title, description }

    @AppStorage("selected_tab") private var selectedTab: Tab = .home

    @State var postTitle: String = ""
    @State var postText: String = ""
    @State var postImageData: Data?

    @AppStorage("user_profile_url") private var profileURL: URL?
    @AppStorage("user_name") private var username: String = ""
    @AppStorage("user_UID") private var userUID: String = ""

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false

    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var showPhotoError: Bool = false

    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Create Post")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top, 15)

                    let sideLength = UIScreen.main.bounds.width - 50

                    Button(action: {
                        showImagePicker = true
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor.opacity(0.05))

                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: sideLength, height: sideLength)
                                    .clipped()
                                    .cornerRadius(12)
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera")
                                        .font(.system(size: 30))
                                        .foregroundColor(.accentColor)

                                    Text("Tap to add a photo")
                                        .font(.footnote)
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .frame(width: sideLength, height: sideLength)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("Add a title", text: $postTitle)
                            .focused($focusedField, equals: .title)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("Add a description", text: $postText, axis: .vertical)
                            .focused($focusedField, equals: .description)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                            )
                            .font(.body)
                            .lineLimit(5)
                    }

                    let isPostDisabled = selectedImage == nil || postTitle.trimmingCharacters(in: .whitespaces).isEmpty

                    Button(action: {
                        focusedField = nil
                        createPost()
                    }) {
                        Text("Post")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isPostDisabled ? Color.gray.opacity(0.3) : Color.accentColor)
                            .foregroundColor(isPostDisabled ? Color.gray : .white)
                            .cornerRadius(12)
                    }
                    .disabled(isPostDisabled)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 60 : 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notif in
                if let keyboardFrame = notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    let height = UIScreen.main.bounds.height - keyboardFrame.origin.y
                    withAnimation {
                        self.keyboardHeight = max(height, 0)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation {
                    self.keyboardHeight = 0
                }
            }
            .onTapGesture {
                focusedField = nil
            }
            .fullScreenCover(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage, showPhotoError: $showPhotoError)
            }
            .alert("Only photos are allowed.", isPresented: $showPhotoError) {
                Button("OK", role: .cancel) {}
            }

            if isLoading {
                LoadingView(show: $isLoading)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: isLoading)
        .alert(errorMessage, isPresented: $showError, actions: {})
        .onChange(of: selectedImage) {
            if let newImage = selectedImage {
                postImageData = newImage.jpegData(compressionQuality: 0.8)
            }
        }
    }

    func createPost() {
        isLoading = true
        Task {
            do {
                guard let profileURL = profileURL else { return }
                guard let activeGroupID = groupsVM.activeGroupID else { return }

                let currentTag = await fetchCurrentTag(for: activeGroupID)
                let imageReferenceID = "\(userUID)\(Date())"
                let storageRef = Storage.storage().reference().child("Post_Images").child(imageReferenceID)

                if let data = postImageData {
                    let _ = try await storageRef.putDataAsync(data)
                    let downloadURL = try await storageRef.downloadURL()

                    let post = Post(
                        title: postTitle,
                        text: postText,
                        imageURL: downloadURL,
                        imageReferenceID: imageReferenceID,
                        publishedDate: Date(),
                        userName: username,
                        userUID: userUID,
                        userProfileURL: profileURL,
                        groupID: activeGroupID,
                        tag: currentTag,
                    )

                    try await createDocumentAtFirebase(post)
                    await groupsVM.handleStreak(for: userUID, groupId: activeGroupID)
                    resetFields()
                } else {
                    let post = Post(
                        title: postTitle,
                        text: postText,
                        publishedDate: Date(),
                        userName: username,
                        userUID: userUID,
                        userProfileURL: profileURL,
                        groupID: activeGroupID,
                        tag: currentTag,
                    )

                    try await createDocumentAtFirebase(post)
                    await groupsVM.handleStreak(for: userUID, groupId: activeGroupID)
                    resetFields()
                }

            } catch {
                await setError(error: error)
            }
        }
    }

    func fetchCurrentTag(for groupID: String) async -> String {
        do {
            let doc = try await Firestore.firestore()
                .collection("Groups")
                .document(groupID)
                .getDocument()
            
            return doc["currentTag"] as? String ?? ""
        } catch {
            return ""
        }
    }

    
    func createDocumentAtFirebase(_ post: Post) async throws {
        var updatedPost = post
        updatedPost.groupID = groupsVM.activeGroupID

        let doc = Firestore.firestore().collection("Posts").document()
        let _ = try doc.setData(from: updatedPost, completion: { error in
            if error == nil {
                isLoading = false
                onPost(updatedPost)
                dismiss()
            }
        })
    }

    func resetFields() {
        postTitle = ""
        postText = ""
        postImageData = nil
        selectedImage = nil
        selectedTab = .home
    }

    func setError(error: Error) async {
        await MainActor.run {
            errorMessage = error.localizedDescription
            showError.toggle()
        }
    }
}
