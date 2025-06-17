import SwiftUI
import PhotosUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// MARK: - RegisterView

struct EditProfileView: View {

    // MARK: - User Input
    @State private var name = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    // MARK: - Profile Picture
    @State private var selectedImage: UIImage? = nil
    @State private var photoItem: PhotosPickerItem?
    @State private var showImagePicker = false
    @State private var userProfilePicData: Data?
    
    // MARK: - AppStorage (to keep data in sync with main app)
    @AppStorage("user_UID") private var userUID: String = ""
    @AppStorage("user_name") private var storedUsername: String = ""
    @AppStorage("user_profile_url") private var profileURL: URL?

    // MARK: - Error & Loading
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    @Environment(\.dismiss) private var dismiss
    var onUpdate: (() -> Void)? = nil

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: - Header
                    Text("Edit Profile")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.top, -5)

                    // MARK: - Profile Picture Picker
                    Button(action: {
                        showImagePicker = true
                    }) {
                        ZStack {
                            if let data = userProfilePicData,
                               let image = UIImage(data: data) {
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
                            if let imageData = try? await newValue.loadTransferable(type: Data.self) {
                                await MainActor.run {
                                    userProfilePicData = imageData
                                }
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

                        SecureField("New Password", text: $password)
                            .textInputAutocapitalization(.never)

                        SecureField("Confirm New Password", text: $confirmPassword)
                            .textInputAutocapitalization(.never)
                    }
                    .padding()
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                    )
                    .padding(.horizontal, 10)

                    // MARK: - Save Button
                    Button(action: {
                        saveChanges()
                    }) {
                        Text("Save Changes")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .fontWeight(.bold)
                            .background(Color.accentColor)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 15)
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                await loadUserData()
            }
        }
        .onAppear {
            Task { await loadUserData() }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
    }
    
    func loadUserData() async {
        await MainActor.run { isLoading = true }

        do {
            let doc = try await Firestore.firestore()
                .collection("Users")
                .document(userUID)
                .getDocument(as: User.self)

            var imageData: Data? = nil

            if let url = doc.userProfileURL {
                let (data, _) = try await URLSession.shared.data(from: url)
                imageData = data
            }

            await MainActor.run {
                name = doc.name
                username = doc.username
                bio = doc.userBio
                email = doc.userEmail
                profileURL = doc.userProfileURL
                userProfilePicData = imageData
                isLoading = false // ✅ Hide loader after finished
            }

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
    
    func saveChanges() {
        isLoading = true
        closeKeyboard()

        Task {
            var downloadURL: URL? = profileURL

            do {
                // 1. Upload new profile image if changed
                if let imageData = userProfilePicData {
                    let ref = Storage.storage().reference().child("Profile_Images").child(userUID)
                    _ = try await ref.putDataAsync(imageData)
                    downloadURL = try await ref.downloadURL()
                }

                // 2. Update Firestore fields
                let userRef = Firestore.firestore().collection("Users").document(userUID)
                var updateData: [String: Any] = [
                    "username": username,
                    "name": name,
                    "userBio": bio,
                    "userEmail": email,
                ]
                if let url = downloadURL {
                    updateData["userProfileURL"] = url.absoluteString
                }

                try await userRef.updateData(updateData)

                // Update local
                storedUsername = username
                profileURL = downloadURL

                // Update auth
                if let currentUser = Auth.auth().currentUser {
                    if email != currentUser.email {
                        try await currentUser.updateEmail(to: email)
                    }
                    if !password.isEmpty {
                        try await currentUser.updatePassword(to: password)
                    }
                }

                await MainActor.run {
                    isLoading = false
                }
                onUpdate?()
                dismiss()
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }

    }

}
