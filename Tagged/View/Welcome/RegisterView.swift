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
    @State private var emailSent       = false   // Show the second button
    @State private var registrationUID = ""      // Keep UID between steps


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

                    VStack(spacing: 8) {
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

                        Text("A profile picture is required")
                            .font(.system(size: 15))
                            .padding(.top, -10)
                    }
                    .frame(maxWidth: .infinity)

                    
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

                    // ---------- FIRST button ----------
                    if !emailSent {
                        Button("Register") {
                            Task {
                                let issues = await localValidation()      // ← already gathers every error
                                if !issues.isEmpty {
                                    errorMessage = issues.joined(separator: "\n• ")
                                    showError = true                      // ← one alert, many lines
                                } else {
                                    createAccountAndSendEmail()
                                }
                            }
                        }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .fontWeight(.bold)
                            .background(Color.accentColor)
                            .cornerRadius(10)
                            .disableWithOpacity(userProfilePicData == nil || username.isEmpty || email.isEmpty || password.isEmpty || confirmPassword != password)
                            .padding(.horizontal,10)
                    }

                    // ---------- SECOND button ----------
                    if emailSent {
                        VStack(spacing: 12) {
                            Text("We’ve emailed a verification link to \(email).\nAfter you click the link, tap the button below to finish.")
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal,15)
                                .padding(.vertical, 10)
                                .foregroundColor(.accentColor)
                            
                            Button("I’ve Verified My Email") {
                                verifyAndFinishRegistration()
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .fontWeight(.bold)
                            .background(Color.accentColor)
                            .cornerRadius(10)
                            .padding(.horizontal,10)
                        }
                    }

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

    func claimUsername(_ username: String, uid: String, userData: [String: Any]) async throws {
        let db = Firestore.firestore()
        let usernamesRef = db.collection("Usernames").document(username.lowercased())
        let userDocRef = db.collection("Users").document(uid)

        try await db.runTransaction { transaction, errorPointer in
            do {
                let existing = try transaction.getDocument(usernamesRef)
                if existing.exists {
                    // Manually set the NSError via the pointer
                    let err = NSError(domain: "", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Username already taken"
                    ])
                    errorPointer?.pointee = err
                    return nil
                }

                transaction.setData(["uid": uid], forDocument: usernamesRef)
                transaction.setData(userData, forDocument: userDocRef)
                print("🟡 Claiming username: \(username.lowercased()) for UID: \(uid)")
                return nil
            } catch {
                // Catch and forward any unexpected Firestore errors
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }




    
    // STEP 1 ──────────────────────────────────────────────────────────
    func createAccountAndSendEmail() {
        isLoading = true
        closeKeyboard()

        Task {
            do {
                // ① create Auth user (no optional binding)
                let result = try await Auth.auth()
                    .createUser(withEmail: email, password: password)
                let authUser = result.user          // ← non-optional `User`
                registrationUID = authUser.uid

                // ② send verification
                try await authUser.sendEmailVerification()

                await MainActor.run { emailSent = true }

            } catch {
                await setError(error)
            }
            isLoading = false
        }
    }

    // STEP 2 ──────────────────────────────────────────────────────────
    func verifyAndFinishRegistration() {
        isLoading = true

        Task {
            do {
                print("🔍 Reloading user...")
                guard let user = Auth.auth().currentUser else {
                    throw NSError(domain: "Auth", code: 0,
                                  userInfo: [NSLocalizedDescriptionKey: "User signed out"])
                }

                try await user.reload()
                print("✅ Reloaded user. Email verified: \(user.isEmailVerified)")

                guard user.isEmailVerified else {
                    throw NSError(domain: "Auth", code: 0,
                                  userInfo: [NSLocalizedDescriptionKey: "Email not verified yet."])
                }

                print("🚀 Starting Firestore profile setup for UID: \(user.uid)")
                try await finishProfileSetup(for: user.uid)

                print("✅ Profile setup complete. Logging in…")
                logStatus = true

            } catch {
                print("❌ Registration failed: \(error.localizedDescription)")
                await setError(error)
            }

            isLoading = false
        }
    }


    // Moves your old Firestore / Storage logic into one helper
    func finishProfileSetup(for userUID: String) async throws {

        // ---- Upload profile picture ----
        guard let imageData = userProfilePicData else {
            throw NSError(domain: "Signup", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Missing profile pic"])
        }

        // 👉 Forces Firebase Storage to use a fresh ID token that contains
        //    "email_verified: true", so Storage rules will pass.
        try await Auth.auth().currentUser?.getIDTokenResult(forcingRefresh: true)   // ← add this line

        let storageRef = Storage.storage()
            .reference().child("Profile_Images").child(userUID)
        
        print("🟡 Storage upload path = Profile_Images/\(userUID)")
        try await storageRef.putDataAsync(imageData)
        print("🟢 Storage upload done, URL fetch next…")
        let downloadURL = try await storageRef.downloadURL()
        print("🟢 Got downloadURL:", downloadURL.absoluteString)

        // ---- Firestore user doc ----
        let userDoc = User(
            username:       username,
            name:           name,
            userBio:        bio,
            userUID:        userUID,
            userEmail:      email,
            userProfileURL: downloadURL,
            userLikeCount:  0
        )
        let encodedUser = try Firestore.Encoder().encode(userDoc)
        try await claimUsername(username.lowercased(),
                                uid: userUID,
                                userData: encodedUser)

        // ---- Join “Tagged Global” ----
        let globalGroupID  = "taggedgroup"
        let globalGroupRef = Firestore.firestore().collection("Groups")
                              .document(globalGroupID)
        let joinedGroups   = Firestore.firestore().collection("Users")
                              .document(userUID).collection("JoinedGroups")

        try await globalGroupRef
            .updateData(["members": FieldValue.arrayUnion([userUID])])

        if let snap = try? await globalGroupRef.getDocument(),
           var meta = try? snap.data(as: Group.self) {
            meta.id = nil
            let joinedData: [String: Any] = [
                "groupMeta":   try Firestore.Encoder().encode(meta),
                "streak":       0,
                "lastPostDate": FieldValue.serverTimestamp(),
                "lastTagWeek":  NSNull(),
                "points":       0
            ]
            try await joinedGroups.document(globalGroupID).setData(joinedData)
        }

        // ---- Persist to AppStorage ----
        UserDefaults.standard.set(globalGroupID, forKey: "active_group_id")
        userNameStored = username
        self.userUID   = userUID
        profileURL     = downloadURL
    }


    // MARK: - Error Handler

    func setError(_ error: Error) async {
        await MainActor.run {
            errorMessage = error.readableAuthMessage   // ← use helper
            showError.toggle()
            isLoading = false
        }
    }
    
    func usernameExists(_ name: String) async -> Bool {
        let doc = try? await Firestore.firestore()
            .collection("Usernames")
            .document(name.lowercased())
            .getDocument()
        return doc?.exists == true
    }
    
    
    func localValidation() async -> [String] {
        var issues = [String]()

        if username.isEmpty { issues.append("Username can’t be empty.") }
        if await usernameExists(username) { issues.append("Username already taken.") }

        let pwdRegex = #"^(?=.*[A-Z])(?=.*[^A-Za-z0-9]).{6,}$"#
        if password.range(of: pwdRegex, options: .regularExpression) == nil {
            issues.append("Password needs 6+ characters, 1 uppercase and 1 symbol.")
        }
        if password != confirmPassword {
            issues.append("Passwords don’t match.")
        }

        return issues
    }

}

extension Error {

    /// A readable, user–facing explanation of any Firebase / Firestore error.
    var readableAuthMessage: String {
        // ── Peel the onion:  look through nested errors ─────────────
        func deepest(_ err: NSError) -> NSError {
            if let inner = err.userInfo[NSUnderlyingErrorKey] as? NSError {
                return deepest(inner)
            }
            return err
        }
        let nserr = deepest(self as NSError)

        // 1️⃣  Your custom Firestore errors (username, etc.)
        if let msg = nserr.userInfo[NSLocalizedDescriptionKey] as? String,
           !msg.localizedCaseInsensitiveContains("internal error") {
            return msg                               // ← "Username already taken"
        }

        // 2️⃣  Standard Firebase Auth codes
        if let code = AuthErrorCode.Code(rawValue: nserr.code) {
            switch code {
            case .emailAlreadyInUse: return "That email is already registered."
            case .invalidEmail:      return "Enter a valid email address."
            case .weakPassword:      return "Password must be at least 6 characters."
            default: break
            }
        }

        // 3️⃣  NEW:  Parse google.HTTPStatus 400 JSON  (password policy, etc.)
        if let data = nserr.userInfo["data"] as? Data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let msg  = (json["error"] as? [String: Any])?["message"] as? String {

            // Example: "PASSWORD_DOES_NOT_MEET_REQUIREMENTS : Missing password requirements: …"
            return msg
                .split(separator: ":")
                .dropFirst()
                .joined(separator: ":")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 4️⃣  Fallback to whatever is left
        return nserr.localizedDescription
    }
}
