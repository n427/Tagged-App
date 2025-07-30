import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    
    @State private var navigateToHome = false
    @Binding var path: NavigationPath

    @State var showError: Bool = false
    @State var errorMessage: String = ""
    @State var isLoading: Bool = false

    @AppStorage("log_status") var logStatus: Bool = false
    @AppStorage("user_profile_url") var profileURL: URL?
    @AppStorage("user_name") var userNameStored: String = ""
    @AppStorage("user_UID") var userUID: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            Text("Let’s Sign You In")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
                .padding(.horizontal, 10)
                .padding(.top, -5)
            
            Text("Welcome back :)")
                .padding(.horizontal, 10)

            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .padding()
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
                .padding(.horizontal, 10)
            
            SecureField("Password", text: $password)
                .textInputAutocapitalization(.never)
                .padding()
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
                .padding(.horizontal, 10)

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

    func resetPassword() {
        Task {
            do {
                try await Auth.auth().sendPasswordReset(withEmail: email)
            } catch {
                await setError(error)
            }
        }
    }

    func setError(_ error: Error) async {
        await MainActor.run {
            errorMessage = "Incorrect email or password. Please try again."
            showError = true
            isLoading = false
        }
    }

}
