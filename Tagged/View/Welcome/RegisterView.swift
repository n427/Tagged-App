import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import PhotosUI

// MARK: - RegisterView

struct RegisterView: View {

    // MARK: - User Input

    @State private var name = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    // MARK: - Navigation

    @State private var navigateToHome = false
    @Binding var path: NavigationPath

    // MARK: - Profile Picture

    @State private var selectedImage: UIImage? = nil
    @State private var photoItem: PhotosPickerItem?
    @State private var showImagePicker = false
    @State private var userProfilePicData: Data?

    // MARK: - Error & Loading State

    @State var showError: Bool = false
    @State var errorMessage: String = ""
    @State var isLoading: Bool = false

    // MARK: - AppStorage

    @AppStorage("log_status") var logStatus: Bool = false
    @AppStorage("user_profile_url") var profileURL: URL?
    @AppStorage("user_name") var userNameStored: String = ""
    @AppStorage("user_UID") var userUID: String = ""

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: - Header

                    Text("Create an Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.top, -5)

                    Text("Let’s get started!")
                        .padding(.horizontal, 10)

                    // MARK: - Profile Picture Picker

                    Button(action: {
                        showImagePicker = true
                    }) {
                        ZStack {
                            if let userProfilePicData,
                               let image = UIImage(data: userProfilePicData) {
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
                    .onChange(of: photoItem) { _, newValue in
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

                    // MARK: - Input Fields

                    SwiftUI.Group {
                        TextField("Name (optional)", text: $name)
                            .textInputAutocapitalization(.never)

                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.never)

                        TextField("Bio (optional)", text: $bio, axis: .vertical)
                            .frame(height: 100, alignment: .top)
                            .textInputAutocapitalization(.never)
                            .lineLimit(5)

                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)

                        SecureField("Password", text: $password)
                            .textInputAutocapitalization(.never)

                        SecureField("Confirm Password", text: $confirmPassword)
                            .textInputAutocapitalization(.never)
                    }
                    .padding()
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
                    .padding(.horizontal, 10)

                    // MARK: - Register Button

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
                    .disableWithOpacity(userProfilePicData == nil || username.isEmpty || email.isEmpty || password.isEmpty || confirmPassword != password || confirmPassword.isEmpty)
                    .padding(.horizontal, 10)

                    Spacer()

                    // MARK: - Footer

                    HStack {
                        Text("Already have an account?")
                            .font(.system(size: 18))

                        Button("Login Here") {
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
            .overlay {
                LoadingView(show: $isLoading)
            }
            .alert(errorMessage, isPresented: $showError, actions: {})
            .navigationBarBackButtonHidden(false)
        }
    }

    // MARK: - Register User

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
                // Create account in Firebase Authentication
                try await Auth.auth().createUser(withEmail: email, password: password)

                guard let userUID = Auth.auth().currentUser?.uid else {
                    throw NSError(domain: "Signup", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing UID"])
                }

                guard let imageData = userProfilePicData else {
                    throw NSError(domain: "Signup", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing profile pic data"])
                }

                // Upload profile picture
                storageRef = Storage.storage().reference().child("Profile_Images").child(userUID)
                let _ = try await storageRef!.putDataAsync(imageData)

                let downloadURL = try await storageRef!.downloadURL()

                // Store user data in Firestore
                let user = User(
                    username: username,
                    name: name,
                    userBio: bio,
                    userUID: userUID,
                    userEmail: email,
                    userProfileURL: downloadURL,
                    userLikeCount: 0
                )

                let encodedUser = try Firestore.Encoder().encode(user)

                try await Firestore.firestore()
                    .collection("Users")
                    .document(userUID)
                    .setData(encodedUser)

                // Store to AppStorage
                userNameStored = username
                self.userUID = userUID
                profileURL = downloadURL
                logStatus = true

            } catch {
                // Cleanup: delete user and uploaded image if something fails
                if let currentUser = Auth.auth().currentUser {
                    try? await currentUser.delete()
                }

                if let ref = storageRef {
                    try? await ref.delete()
                }

                await setError(error)
            }
        }
    }

    // MARK: - Error Handler

    func setError(_ error: Error) async {
        await MainActor.run {
            errorMessage = error.localizedDescription
            showError.toggle()
            isLoading = false
        }
    }
}

// MARK: - Preview

struct RegisterView_Previews: PreviewProvider {
    @State static var path = NavigationPath()

    static var previews: some View {
        RegisterView(path: $path)
    }
}
