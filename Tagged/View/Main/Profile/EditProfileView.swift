import SwiftUI
import PhotosUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage


struct EditProfileView: View {

    @State private var name = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    @State private var selectedImage: UIImage? = nil
    @State private var photoItem: PhotosPickerItem?
    @State private var showImagePicker = false
    @State private var userProfilePicData: Data?
    
    @AppStorage("user_UID") private var userUID: String = ""
    @AppStorage("user_name") private var storedUsername: String = ""
    @AppStorage("user_profile_url") private var profileURL: URL?

    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    @State private var usernameTaken   = false
    @State private var checkingName    = false

    
    @Environment(\.dismiss) private var dismiss
    var onUpdate: (() -> Void)? = nil

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    Text("Edit Profile")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.top, -5)

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

                    SwiftUI.Group {
                        TextField("Name (optional)", text: $name)
                            .textInputAutocapitalization(.never)

                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.never)
                            .onChange(of: username) { _, newValue in
                                usernameTaken = false
                                checkingName  = true
                                
                                Task {
                                    let want = newValue.trimmingCharacters(in: .whitespaces)
                                    let have = storedUsername.trimmingCharacters(in: .whitespaces)
                                    guard !want.isEmpty, want.lowercased() != have.lowercased() else {
                                        await MainActor.run { checkingName = false }
                                        return
                                    }
                                    
                                    let exists = try? await Firestore.firestore()
                                        .collection("Usernames")
                                        .document(want.lowercased())
                                        .getDocument()
                                    
                                    await MainActor.run {
                                        usernameTaken = exists?.exists ?? false
                                        checkingName  = false
                                    }
                                }
                            }

                        TextField("Bio (optional)", text: $bio, axis: .vertical)
                            .frame(height: 100, alignment: .top)
                            .textInputAutocapitalization(.never)
                            .lineLimit(5)

                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .disabled(true)

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

                    Button(action: { saveChanges() }) {
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
                    .disableWithOpacity(
                        isLoading ||
                        username.trimmingCharacters(in: .whitespaces).isEmpty ||
                        email.trimmingCharacters(in: .whitespaces).isEmpty
                    )
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            Task { await loadUserData() }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: isLoading)
        .overlay {
            if isLoading {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.accentColor.opacity(0.05))
                        .frame(width: 40, height: 40)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.accentColor))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }

        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
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
                isLoading = false
            }

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
    
    func passwordError(_ pwd: String) -> String? {
        guard pwd.count >= 8 else { return "Password must be 8+ characters." }
        guard pwd.rangeOfCharacter(from: .uppercaseLetters) != nil else { return "Add an uppercase letter." }
        guard pwd.rangeOfCharacter(from: .lowercaseLetters) != nil else { return "Add a lowercase letter." }
        guard pwd.rangeOfCharacter(from: .decimalDigits)     != nil else { return "Add a digit." }
        guard pwd.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()-_=+{}[]|:;\"'<>,.?/`~")) != nil
            else { return "Add a symbol." }
        return nil
    }
    
    func localValidation() async -> [String] {
        var problems: [String] = []

        let desired = username.trimmingCharacters(in: .whitespaces)
        let current = storedUsername.trimmingCharacters(in: .whitespaces)

        if desired.isEmpty {
            problems.append("Username can’t be empty.")
        } else if desired.lowercased() != current.lowercased() {
            let doc = try? await Firestore.firestore()
                         .collection("Usernames")
                         .document(desired.lowercased())
                         .getDocument()
            if doc?.exists == true {
                problems.append("Username already taken.")
            }
        }

        if !password.isEmpty || !confirmPassword.isEmpty {
            let pwd = password
            if pwd.count < 6 ||
               pwd.rangeOfCharacter(from: .uppercaseLetters) == nil ||
               pwd.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil {
                problems.append("Password needs ≥6 chars, 1 uppercase, 1 symbol.")
            }
            if pwd != confirmPassword {
                problems.append("Passwords don’t match.")
            }
        }

        return problems
    }

    func saveChanges() {
        isLoading = true
        closeKeyboard()

        Task {
            let newUsername = username.trimmingCharacters(in: .whitespaces)
            let oldUsername = storedUsername
            var issues: [String] = []

            if newUsername.lowercased() != oldUsername.lowercased() {
                let nameDoc = try? await Firestore.firestore()
                    .collection("Usernames")
                    .document(newUsername.lowercased())
                    .getDocument()
                if nameDoc?.exists == true {
                    issues.append("Username already taken.")
                }
            }

            if !password.isEmpty {
                if password.count < 6 {
                    issues.append("Password must be 6+ characters.")
                }
                if password.rangeOfCharacter(from: .uppercaseLetters) == nil {
                    issues.append("Add an uppercase letter.")
                }
                if password.rangeOfCharacter(from: .lowercaseLetters) == nil {
                    issues.append("Add a lowercase letter.")
                }
                if password.rangeOfCharacter(from: .decimalDigits) == nil {
                    issues.append("Add a digit.")
                }
                if password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()-_=+{}[]|:;\"'<>,.?/`~")) == nil {
                    issues.append("Add a symbol.")
                }
            }

            if password != confirmPassword {
                issues.append("Passwords do not match.")
            }

            if !issues.isEmpty {
                await MainActor.run {
                    errorMessage = issues.joined(separator: "\n• ")
                    showError = true
                    isLoading = false
                }
                return
            }

            do {
                var downloadURL = profileURL
                if let imageData = userProfilePicData {
                    let ref = Storage.storage()
                        .reference()
                        .child("Profile_Images")
                        .child(userUID)
                    _ = try await ref.putDataAsync(imageData)
                    downloadURL = try await ref.downloadURL()
                }

                var updateData: [String: Any] = [
                    "username": newUsername,
                    "name": name,
                    "userBio": bio,
                    "userEmail": email
                ]
                if let url = downloadURL {
                    updateData["userProfileURL"] = url.absoluteString
                }
                let userRef = Firestore.firestore()
                    .collection("Users")
                    .document(userUID)
                try await userRef.updateData(updateData)

                if newUsername.lowercased() != oldUsername.lowercased() {
                    let db = Firestore.firestore()
                    let batch = db.batch()
                    batch.deleteDocument(db.collection("Usernames").document(oldUsername.lowercased()))
                    batch.setData(["uid": userUID], forDocument: db.collection("Usernames").document(newUsername.lowercased()))
                    try await batch.commit()
                }

                if let authUser = Auth.auth().currentUser {
                    if email != authUser.email {
                        try await authUser.sendEmailVerification(beforeUpdatingEmail: email)
                    }
                    if !password.isEmpty {
                        try await authUser.updatePassword(to: password)
                    }
                }

                await MainActor.run {
                    storedUsername = newUsername
                    profileURL = downloadURL
                    isLoading = false
                    onUpdate?()
                    dismiss()
                }

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
