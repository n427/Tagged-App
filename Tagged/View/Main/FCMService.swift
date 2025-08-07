import FirebaseMessaging
import FirebaseFirestore

struct FCMService {
    static func saveFCMToken(forUID uid: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)

        let token = try await Messaging.messaging().token()

        try await Firestore.firestore()
            .collection("Users")
            .document(uid)
            .updateData(["fcmToken": token])
    }
}
