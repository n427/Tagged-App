import SwiftUI
import FirebaseFirestore

struct LazyProfileLoaderView: View {
    let userUID: String
    let groupID: String?
    let currentUserUID: String

    @State private var loadedUser: User?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        SwiftUI.Group {
            if let user = loadedUser {
                ReusableProfileContent(
                    user: user,
                    isMyProfile: user.userUID == currentUserUID,
                    selectedGroupAdminID: nil,
                    activeGroupID: groupID
                )
            } else if let errorMessage = errorMessage {
                Text("⚠️ \(errorMessage)")
            } else {
                ProgressView("Loading...")
            }
        }
        .task {
            do {
                let user = try await Firestore.firestore()
                    .collection("Users")
                    .document(userUID)
                    .getDocument(as: User.self)
                self.loadedUser = user
            } catch {
                self.errorMessage = "User not found"
            }
        }
    }
}
