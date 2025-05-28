//
//  CreateNewPost.swift
//  Tagged
//
//  Created by Nicole Zhang on 2025-05-27.
//

import SwiftUI
import PhotosUI
import Firebase
import FirebaseStorage

struct CreateNewPost: View {
    var onPost: (Post)-> ()
    
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
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoError: Bool = false
    
    @FocusState private var showKeyboard: Bool
    
    var body: some View {
        VStack() {
            HStack {
                Text("Create Post")
                    .font(.system(size: 30))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 7)
            .padding(.bottom, 10)
            
            // Selected Image or Camera Selector
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIScreen.main.bounds.width - 40, height: UIScreen.main.bounds.width - 40)
                    .clipped()
                    .cornerRadius(5)
                    .padding(.horizontal)
                    .onTapGesture {
                        showImagePicker = true
                    }
                    .padding(.horizontal, 10)
            } else {
                Button(action: {
                    showImagePicker = true
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.accentColor.opacity(0.05))
                            .frame(width: UIScreen.main.bounds.width - 40, height: UIScreen.main.bounds.width - 40)
                        
                        Image(systemName: "camera")
                            .font(.system(size: 40))
                            .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal, 10)
                }
                .padding(.horizontal)
            }
            
            // Title & Description
            VStack(spacing: 12) {
                TextField("Add a title", text: $postTitle)
                    .font(.title3)
                    .padding(.horizontal)
                    .fontWeight(.bold)
                
                TextField("Add a decription", text: $postText, axis: .vertical)
                    .lineLimit(4)
                    .padding(.horizontal)
            }
            .padding(.top, 10)
            
            
            .padding(.horizontal, 10)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        
        .fullScreenCover(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage, showPhotoError: $showPhotoError)
        }
        
        .alert("Only photos are allowed.", isPresented: $showPhotoError) {
            Button("OK", role: .cancel) {}
        }
        
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                HStack {
                    Spacer(minLength: 20)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                    Spacer(minLength: 20)
                }
                .padding(.bottom, 5)
                
                let isPostDisabled = selectedImage == nil || postTitle.trimmingCharacters(in: .whitespaces).isEmpty
                
                Button(action: {
                    createPost()
                }) {
                    Text("Post")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isPostDisabled ? Color.gray.opacity(0.3) : Color.accentColor)
                        .foregroundColor(isPostDisabled ? Color.gray : .white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                .disabled(isPostDisabled)
            }
            .padding(.bottom)
            
            
        }
            
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .alert(errorMessage, isPresented: $showError, actions: {})
        
        .onChange(of: selectedImage) {
            if let newImage = selectedImage {
                if let data = newImage.jpegData(compressionQuality: 0.8) {
                    postImageData = data
                }
            }
        }
        
        .overlay {
            LoadingView(show: $isLoading)
        }
    }
    
    func createPost() {
        isLoading = true
        showKeyboard = false
        Task {
            do {
                guard let profileURL = profileURL else {return}
                let imageReferenceID = "\(userUID)\(Date())"
                let storageRef = Storage.storage().reference().child("Post_Images").child(imageReferenceID)
                if let data = postImageData {
                    let _ = try await storageRef.putDataAsync(data)
                    let downloadURL = try await storageRef.downloadURL()

                    let post = Post(title: postTitle, text: postText, imageURL: downloadURL, imageReferenceID: imageReferenceID, userName: username, userUID: userUID, userProfileURL: profileURL)
                    try await createDocumentAtFirebase(post)

                    postTitle = ""
                    postText = ""
                    postImageData = nil
                    selectedImage = nil
                    selectedTab = .home
                }else {
                    let post = Post(title: postTitle, text: postText, userName: username, userUID: userUID, userProfileURL: profileURL)
                    try await createDocumentAtFirebase(post)
                    postTitle = ""
                    postText = ""
                    postImageData = nil
                    selectedImage = nil
                    selectedTab = .home
                }
                
            }
            catch {
                await setError(error: error)
            }
        }
    }
    
    func createDocumentAtFirebase(_ post: Post)async throws {
        let _ = try Firestore.firestore().collection("Posts").addDocument(from: post, completion:  {error in
            if error == nil {
                isLoading = false
                onPost(post)
                dismiss()
            }
        })
    }
    
    func setError(error: Error)async {
        await MainActor.run(body: {
            errorMessage = error.localizedDescription
            showError.toggle()
        })
    }
}

struct CreateNewPost_Previews: PreviewProvider {
    static var previews: some View {
        CreateNewPost{_ in
            
        }
    }
}
