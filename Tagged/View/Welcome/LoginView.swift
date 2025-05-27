import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var navigateToHome = false
    @State var showError: Bool = false
    @State var errorMessage: String = ""
    @Binding var path: NavigationPath
    @State var isLoading: Bool = false
    
    @AppStorage("log_status") var logStatus: Bool = false
    @AppStorage("user_profile_url") var profileURL: URL?
    @AppStorage("user_name") var userNameStored: String = ""
    @AppStorage("user_UID") var userUID: String = ""

    var body: some View {
        
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
            
            Text("Let’s Sign You In")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
                .padding(.horizontal, 10)
            
            Text("Welcome back :)")
                .padding(.horizontal, 10)

            // Email Field
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .padding()
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                .padding(.horizontal, 10)
            
            // Password Field
            SecureField("Password", text: $password)
                .textInputAutocapitalization(.never)
                .padding()
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                .padding(.horizontal, 10)

            // Reset Password Link
            HStack {
                Spacer()
                Button(action: {resetPassword()}) {
                    Text("Reset Password?")
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.top, -10)
                }
            }

            // Login Button
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

            // Register Link
            HStack {
                Text("Don’t have an account?")
                    .font(.system(size: 18))
                Button("Register Now"){
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
        .overlay(content: {
            LoadingView(show: $isLoading)
        })
        .navigationBarBackButtonHidden(true)
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
            }
            catch {
                await setError(error)
            }
        }
    }
    
    func fetchUser() async throws {
        guard let userID = Auth.auth().currentUser?.uid else {return}
        let user = try await Firestore.firestore().collection("Users").document(userID).getDocument(as: User.self)
        
        await MainActor.run(body: {
            userUID = userID
            userNameStored = user.username
            profileURL = user.userProfileURL
            logStatus = true
        })
    }
    
    func resetPassword() {
        Task {
            do {
                try await Auth.auth().sendPasswordReset(withEmail:email)
                print("Link sent")
            }
            catch {
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

struct LoginView_Previews: PreviewProvider {
    @State static var path = NavigationPath()
    
    static var previews: some View {
        LoginView(path: $path)
    }
}
