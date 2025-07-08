import SwiftUI
import Firebase
import FirebaseStorage
import FirebaseFirestore

// MARK: - ProfileView

struct ProfileView: View {
    @State private var myProfile: User?
    @AppStorage("log_status") var logStatus: Bool = false
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var isLoading: Bool = false

    // Inject these from parent
    @ObservedObject var groupsVM: GroupsViewModel
    var activeGroupID: String?


    var body: some View {
        let selectedGroupAdminID = groupsVM.myJoinedGroups
            .first { $0.groupID == activeGroupID }?
            .groupMeta.adminID
        NavigationStack {
            if let unwrappedProfile = myProfile {
                ReusableProfileContent(
                    user: unwrappedProfile,
                    isMyProfile: true,
                    selectedGroupAdminID: selectedGroupAdminID,
                    activeGroupID: activeGroupID,
                    logOutAction: logOutUser,
                    deleteAccountAction: deleteAccount,
                    onUpdate: { Task { await fetchUserData() } }
                )
                .padding(.top, 12)
                .refreshable {
                    // Pull to refresh reloads profile data
                    self.myProfile = nil
                    await fetchUserData()
            }
            }else {
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
                guard let user = Auth.auth().currentUser else { return }
                let uid = user.uid
                let db = Firestore.firestore()
                let storage = Storage.storage()

                // 1️⃣ Delete profile image from Storage
                try? await storage.reference()
                    .child("Profile_Images")
                    .child(uid)
                    .delete()

                // 2️⃣ Fetch groupIDs from JoinedGroups
                let joinedSnap = try await db.collection("Users")
                    .document(uid)
                    .collection("JoinedGroups")
                    .getDocuments()
                let groupIDs = joinedSnap.documents.map { $0.documentID }

                // 3️⃣ Batch remove from group members and delete joined mirrors
                let batch = db.batch()
                for gid in groupIDs {
                    let groupRef = db.collection("Groups").document(gid)
                    let joinedRef = db.collection("Users").document(uid)
                        .collection("JoinedGroups").document(gid)

                    batch.updateData(["members": FieldValue.arrayRemove([uid])], forDocument: groupRef)
                    batch.deleteDocument(joinedRef)
                }

                // 4️⃣ Delete `Usernames/{username}` and `Users/{uid}`
                let username = user.displayName ?? uid
                batch.deleteDocument(db.collection("Usernames").document(username))
                batch.deleteDocument(db.collection("Users").document(uid))
                try await batch.commit()

                // 5️⃣ Delete their posts and post images
                let postSnap = try await db.collection("Posts")
                    .whereField("userUID", isEqualTo: uid)
                    .getDocuments()

                for doc in postSnap.documents {
                    if let ref = doc["imageReferenceID"] as? String {
                        try? await storage.reference()
                            .child("Post_Images")
                            .child(ref)
                            .delete()
                    }
                    try? await doc.reference.delete()
                }

                // 6️⃣ Finally, delete Firebase Auth account
                try await user.delete()

                // 7️⃣ Log user out
                await MainActor.run {
                    logStatus = false
                }

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
