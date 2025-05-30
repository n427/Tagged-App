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
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Create Post")
                        .font(.title)
                        .fontWeight(.bold)

                    // Image Picker
                    // Screen width minus 2×25 (your horizontal padding)
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


                    // Title Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("Add a title", text: $postTitle)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .font(.body)
                            .focused($showKeyboard)
                    }

                    // Description Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("Add a description", text: $postText, axis: .vertical)
                            .lineLimit(5)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .font(.body)
                            .focused($showKeyboard)
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 25)
                .padding(.top)

            }
            .fullScreenCover(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage, showPhotoError: $showPhotoError)
            }
            .alert("Only photos are allowed.", isPresented: $showPhotoError) {
                Button("OK", role: .cancel) {}
            }

            // POST BUTTON
            VStack {
                Spacer()

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
                .padding(.bottom, 20)
                .padding(.horizontal, 7)
                .background(Color.white.opacity(0.95)) // Lift from bottom
            }

            if isLoading {
                LoadingView(show: $isLoading)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .alert(errorMessage, isPresented: $showError, actions: {})
        .onChange(of: selectedImage) {
            if let newImage = selectedImage {
                postImageData = newImage.jpegData(compressionQuality: 0.8)
            }
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
