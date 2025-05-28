import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import PhotosUI

struct RegisterView: View {
    @State private var name = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var navigateToHome = false

    @State private var selectedImage: UIImage? = nil
    @State private var photoItem: PhotosPickerItem?
    @State private var showImagePicker = false
    @State private var userProfilePicData: Data?
    
    @State var showError: Bool = false
    @State var errorMessage: String = ""
    @State var isLoading: Bool = false
    
    @Binding var path: NavigationPath
    
    //User defaults
    @AppStorage("log_status") var logStatus: Bool = false
    @AppStorage("user_profile_url") var profileURL: URL?
    @AppStorage("user_name") var userNameStored: String = ""
    @AppStorage("user_UID") var userUID: String = ""

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Button(action: {
                            path.removeLast(path.count) // Go back to root
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .padding([.top, .leading, .trailing])
                            .padding(.top, -30)
                            .padding(.horizontal, -5)
                            .foregroundColor(.accentColor) // Custom color for the back button
                        }
                    }
                    
                    Text("Create an Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 10)

                    Text("Let’s get started!")
                        .padding(.horizontal, 10)

                    // Profile Picture
                    Button(action: {
                        showImagePicker = true
                    }) {
                        ZStack {
                            if let userProfilePicData, let image = UIImage(data: userProfilePicData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(.systemGray6))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: "camera")
                                            .font(.system(size: 28))
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .photosPicker(isPresented: $showImagePicker, selection: $photoItem)
                    .onChange(of: photoItem) { oldValue, newValue in
                        guard let newValue else { return }
                        Task {
                            do {
                                guard let imageData = try await newValue.loadTransferable(type: Data.self) else { return }
                                await MainActor.run {
                                    userProfilePicData = imageData
                                }
                            } catch {
                                print("Image loading error:", error)
                            }
                        }
                    }

                    // Form Fields
                    Group {
                        TextField("Name (optional)", text: $name)
                            .textInputAutocapitalization(.never)
                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.never)
                        TextField("Bio (optional)", text: $bio)
                            .frame(height: 100, alignment: .top)
                            .textInputAutocapitalization(.never)
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                        SecureField("Password", text: $password)
                            .textInputAutocapitalization(.never)
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textInputAutocapitalization(.never)
                    }
                    .padding()
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                    .padding(.horizontal, 10)

                    // Register Button
                    Button(action: {
                        registerUser()
                    }) {
                        Text("Register")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .fontWeight(.bold)
                            .background(Color.accentColor)
                            .cornerRadius(10)
                    }
                    .disableWithOpacity(userProfilePicData == nil || username == "" || email == "" || password == "" || confirmPassword != password || confirmPassword == "")
                    .padding(.horizontal, 10)

                    Spacer()

                    // Footer
                    HStack {
                        Text("Already have an account?")
                            .font(.system(size: 18))
                        Button("Login Here"){
                            path.append(AppRoute.login)
                        }
                            .fontWeight(.bold)
                            .font(.system(size: 18))
                            .foregroundColor(.accentColor)
                    }
                    .font(.footnote)
                    .padding(.bottom)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding()
            }
            .overlay(content: {
                LoadingView(show: $isLoading)
            })
            .alert(errorMessage, isPresented: $showError, actions: {})
            .navigationBarBackButtonHidden(true)

        }
    }
    
    
    func registerUser() {
        isLoading = true
        closeKeyboard()
        Task {
            var storageRef: StorageReference? = nil
            defer {
                Task { @MainActor in
                    isLoading = false
                }
            }
            do {
                print("Creating user...")
                try await Auth.auth().createUser(withEmail: email, password: password)
                print("Firebase Auth Success")

                guard let userUID = Auth.auth().currentUser?.uid else {
                    print("Missing UID")
                    throw NSError(domain: "Signup", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing UID"])
                }

                guard let imageData = userProfilePicData else {
                    print("Missing profile pic data")
                    throw NSError(domain: "Signup", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing profile pic data"])
                }

                storageRef = Storage.storage().reference().child("Profile_Images").child(userUID)
                print("Uploading image...")
                let _ = try await storageRef!.putDataAsync(imageData)
                print("Image uploaded")

                let downloadURL = try await storageRef!.downloadURL()
                print("Got download URL: \(downloadURL)")

                let user = User(
                    username: username,
                    name: name,
                    userBio: bio,
                    userUID: userUID,
                    userEmail: email,
                    userProfileURL: downloadURL
                )
                
                let encodedUser = try Firestore.Encoder().encode(user)
                print("User encoded")

                try await Firestore.firestore().collection("Users").document(userUID).setData(encodedUser)
                print("Firestore save success")
                userNameStored = username
                self.userUID = userUID
                profileURL = downloadURL
                logStatus = true

            } catch {
                print("ERROR: \(error.localizedDescription)")

                // Always delete user if created
                if let currentUser = Auth.auth().currentUser {
                    do {
                        print("Deleting user due to signup error...")
                        try await currentUser.delete()
                        print("User deleted successfully.")
                    } catch {
                        print("Failed to delete user: \(error.localizedDescription)")
                    }
                }

                // Always delete uploaded profile pic if storageRef exists
                if let ref = storageRef {
                    do {
                        print("Deleting uploaded profile pic due to signup error...")
                        try await ref.delete()
                        print("Profile pic deleted successfully.")
                    } catch {
                        print("Failed to delete profile pic: \(error.localizedDescription)")
                    }
                }
                await setError(error)
            }
        }
        
    }
    
    //Errors
    func setError(_ error: Error)async{
        await MainActor.run(body: {
            errorMessage = error.localizedDescription
            showError.toggle()
            isLoading = false
        })
    }
    
}

struct RegisterView_Previews: PreviewProvider {
    @State static var path = NavigationPath()
    
    static var previews: some View {
        RegisterView(path: $path)
    }
}
