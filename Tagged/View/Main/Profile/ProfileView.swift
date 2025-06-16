import SwiftUI
import Firebase
import FirebaseStorage
import FirebaseFirestore

// MARK: - ProfileView

struct ProfileView: View {
    @State private var myProfile: User? // Holds the current user's profile
    @AppStorage("log_status") var logStatus: Bool = false // Login state

    @State private var errorMessage: String = "" // Error message text
    @State private var showError: Bool = false // Toggles error alert
    @State private var isLoading: Bool = false // Toggles loading view

    var body: some View {
        NavigationStack {
            if let myProfile {
                // Profile display with logout and delete actions
                ReusableProfileContent(
                    user: myProfile,
                    isMyProfile: true,
                    logOutAction: logOutUser,
                    deleteAccountAction: deleteAccount
                )
                .padding(.top, 12)
                .refreshable {
                    // Pull to refresh reloads profile data
                    self.myProfile = nil
                    await fetchUserData()
                }
            } else {
                // Empty view while loading
                Color.clear
            }
        }
        .overlay {
            // Show loading spinner
            LoadingView(show: $isLoading)
        }
        .alert(errorMessage, isPresented: $showError) {} // Show error alert
        .task {
            // Load user on view appear if not already loaded
            if myProfile == nil {
                await fetchUserData()
            }
        }
    }

    // MARK: - Fetch User Data

    func fetchUserData() async {
        guard let userUID = Auth.auth().currentUser?.uid else { return }

        do {
            // Fetch user document from Firestore
            let user = try await Firestore.firestore()
                .collection("Users")
                .document(userUID)
                .getDocument(as: User.self)

            // Update UI on main thread
            await MainActor.run {
                myProfile = user
            }
        } catch {
            await setError(error)
        }
    }

    // MARK: - Logout

    func logOutUser() {
        try? Auth.auth().signOut() // Sign out from Firebase
        logStatus = false // Update login status
    }

    // MARK: - Delete Account

    func deleteAccount() {
        isLoading = true
        Task {
            do {
                guard let userUID = Auth.auth().currentUser?.uid else { return }

                // Delete profile image from Storage
                let reference = Storage.storage()
                    .reference()
                    .child("Profile_Images")
                    .child(userUID)
                try await reference.delete()

                // Delete user document from Firestore
                try await Firestore.firestore()
                    .collection("Users")
                    .document(userUID)
                    .delete()

                // Delete account from Firebase Auth
                try await Auth.auth().currentUser?.delete()
                logStatus = false
            } catch {
                await setError(error)
            }
        }
    }

    // MARK: - Error Handling

    func setError(_ error: Error) async {
        // Update UI to show error
        await MainActor.run {
            isLoading = false
            errorMessage = error.localizedDescription
            showError.toggle()
        }
    }
}

// MARK: - Preview

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
