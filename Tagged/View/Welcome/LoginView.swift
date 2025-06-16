import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

// MARK: - LoginView

struct LoginView: View {
    
    // MARK: - User Input
    
    @State private var email = ""
    @State private var password = ""
    
    // MARK: - Navigation and State

    @State private var navigateToHome = false
    @Binding var path: NavigationPath

    // MARK: - UI State

    @State var showError: Bool = false
    @State var errorMessage: String = ""
    @State var isLoading: Bool = false

    // MARK: - Persistent Storage

    @AppStorage("log_status") var logStatus: Bool = false
    @AppStorage("user_profile_url") var profileURL: URL?
    @AppStorage("user_name") var userNameStored: String = ""
    @AppStorage("user_UID") var userUID: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // MARK: - Header

            Text("Let’s Sign You In")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
                .padding(.horizontal, 10)
                .padding(.top, -5)
            
            Text("Welcome back :)")
                .padding(.horizontal, 10)

            // MARK: - Email Field

            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .padding()
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
                .padding(.horizontal, 10)
            
            // MARK: - Password Field

            SecureField("Password", text: $password)
                .textInputAutocapitalization(.never)
                .padding()
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
                .padding(.horizontal, 10)

            // MARK: - Reset Password

            HStack {
                Spacer()
                Button(action: { resetPassword() }) {
                    Text("Reset Password?")
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.top, -10)
                }
            }

            // MARK: - Login Button

            Button(action: {
                loginUser()
            }) {
                Text("Login")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .fontWeight(.bold)
                    .background(Color.accentColor)
                    .cornerRadius(10)
                    .padding(.horizontal, 10)
            }
            .disableWithOpacity(email == "" || password == "")

            Spacer()

            // MARK: - Register Link

            HStack {
                Text("Don’t have an account?")
                    .font(.system(size: 18))
                Button("Register Now") {
                    path.append(AppRoute.register)
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
        .overlay {
            LoadingView(show: $isLoading)
        }
        .navigationBarBackButtonHidden(false)
        .alert(errorMessage, isPresented: $showError, actions: {})
    }

    // MARK: - Login Logic

    func loginUser() {
        isLoading = true
        closeKeyboard()
        
        Task {
            defer {
                Task { @MainActor in
                    isLoading = false
                }
            }

            do {
                try await Auth.auth().signIn(withEmail: email, password: password)
                try await fetchUser()
            } catch {
                await setError(error)
            }
        }
    }

    // MARK: - Fetch User Data from Firestore

    func fetchUser() async throws {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        let user = try await Firestore.firestore()
            .collection("Users")
            .document(userID)
            .getDocument(as: User.self)

        await MainActor.run {
            userUID = userID
            userNameStored = user.username
            profileURL = user.userProfileURL
            logStatus = true
        }
    }

    // MARK: - Reset Password

    func resetPassword() {
        Task {
            do {
                try await Auth.auth().sendPasswordReset(withEmail: email)
                print("Link sent")
            } catch {
                await setError(error)
            }
        }
    }

    // MARK: - Error Handling

    func setError(_ error: Error) async {
        await MainActor.run {
            errorMessage = error.localizedDescription
            showError.toggle()
            isLoading = false
        }
    }
}

// MARK: - Preview

struct LoginView_Previews: PreviewProvider {
    @State static var path = NavigationPath()

    static var previews: some View {
        LoginView(path: $path)
    }
}
