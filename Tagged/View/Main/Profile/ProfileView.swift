import SwiftUI
import Firebase
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

struct ProfileView: View {
    @State private var myProfile: User?
    @State private var isProfileLoaded = false
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var isLoading: Bool = false

    @AppStorage("log_status") var logStatus: Bool = false
    @AppStorage("user_UID") var userUID: String = ""
    @AppStorage("user_name") var userNameStored: String = ""
    @AppStorage("user_profile_url") var profileURL: URL?

    @ObservedObject var groupsVM: GroupsViewModel
    var activeGroupID: String?

    var body: some View {
        let selectedGroupAdminID = groupsVM.myJoinedGroups
            .first { $0.groupID == activeGroupID }?
            .groupMeta.adminID

        NavigationStack {
            ZStack {
                if let unwrappedProfile = myProfile, isProfileLoaded {
                    ReusableProfileContent(
                        user: unwrappedProfile,
                        isMyProfile: unwrappedProfile.userUID == userUID,
                        selectedGroupAdminID: selectedGroupAdminID,
                        activeGroupID: activeGroupID,
                        logOutAction: logOutUser,
                        deleteAccountAction: deleteAccount,
                        onUpdate: { Task { await fetchUserData() } }
                    )
                    .id("\(unwrappedProfile.userUID)_\(activeGroupID ?? "")")
                    .padding(.top, 12)
                } else {
                    VStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.accentColor.opacity(0.05))
                                .frame(width: 40, height: 40)
                            
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.accentColor))
                                .scaleEffect(1)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isLoading)
        }
        .overlay {
            LoadingView(show: $isLoading)
        }
        .alert(errorMessage, isPresented: $showError) {}
        .task {
            if myProfile == nil {
                await fetchUserData()
            }
        }
    }

    func fetchUserData() async {
        guard let currentUID = Auth.auth().currentUser?.uid else { return }

        do {
            let user = try await Firestore.firestore()
                .collection("Users")
                .document(currentUID)
                .getDocument(as: User.self)

            await MainActor.run {
                self.myProfile = user
                self.isProfileLoaded = true
            }
        } catch {
            await setError(error)
        }
    }

    func logOutUser() {
        Task {
            do {
                groupsVM.reset()
                try Auth.auth().signOut()
                await MainActor.run {
                    logStatus = false
                    userUID = ""
                    userNameStored = ""
                    profileURL = nil
                    myProfile = nil
                    isProfileLoaded = false
                    
                }
            } catch {
                await setError(error)
            }
        }
    }
    
    func deleteAccount() {
        isLoading = true
        Task {
            do {
                groupsVM.reset()
                guard let user = Auth.auth().currentUser else { return }
                let uid = user.uid
                let db = Firestore.firestore()
                let storage = Storage.storage()

                try? await storage.reference()
                    .child("Profile_Images")
                    .child(uid)
                    .delete()

                let joinedSnap = try await db.collection("Users")
                    .document(uid)
                    .collection("JoinedGroups")
                    .getDocuments()
                let groupIDs = joinedSnap.documents.map { $0.documentID }

                let batch = db.batch()
                for gid in groupIDs {
                    batch.updateData(["members": FieldValue.arrayRemove([uid])], forDocument: db.collection("Groups").document(gid))
                    batch.deleteDocument(db.collection("Users").document(uid).collection("JoinedGroups").document(gid))
                }

                let username = user.displayName ?? uid
                batch.deleteDocument(db.collection("Usernames").document(username))
                batch.deleteDocument(db.collection("Users").document(uid))
                try await batch.commit()

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

                try await user.delete()
                await MainActor.run {
                    logStatus = false
                }
            } catch {
                await setError(error)
            }
        }
    }

    func setError(_ error: Error) async {
        await MainActor.run {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            self.showError.toggle()
        }
    }
}
