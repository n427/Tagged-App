import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

@MainActor
final class GroupsViewModel: ObservableObject {
    @Published var myJoinedGroups: [JoinedGroup] = []

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()
    private let userUID: String

    @AppStorage("stored_active_group_id") private var storedActiveGroupID: String?
    @Published var activeGroupID: String? {
        didSet {
            if let activeGroupID = activeGroupID {
                storedActiveGroupID = activeGroupID
            }
        }
    }

    init(userUID: String) {
        self.userUID = userUID
        listenToJoinedGroups()
    }

    @MainActor
    func refreshJoinedGroups() async {
        do {
            let snap = try await db.collection("Users")
                .document(userUID)
                .collection("JoinedGroups")
                .getDocuments()

            myJoinedGroups = try snap.documents.compactMap {
                try $0.data(as: JoinedGroup.self)
            }
        } catch {
            print("❌ refreshJoinedGroups:", error)
        }
    }

    func listenToJoinedGroups() {
        listener = db.collection("Users")
            .document(userUID)
            .collection("JoinedGroups")
            .addSnapshotListener { [weak self] snap, err in
                guard let self,
                      let docs = snap?.documents,
                      err == nil else { return }

                var fetched: [JoinedGroup] = []

                for doc in docs {
                    do {
                        var joined = try doc.data(as: JoinedGroup.self)
                        joined.id = doc.documentID          // optional: keep local id
                        fetched.append(joined)
                    } catch {
                        print("❌ JoinedGroup decode failed:", error)
                    }
                }

                print("👤 Listening for userUID:", userUID)

                self.myJoinedGroups = fetched
                print("✅ Loaded \(myJoinedGroups.count) joined groups")
                
                // Auto-select stored group or fallback
                if let storedID = self.storedActiveGroupID,
                   fetched.contains(where: { $0.groupID == storedID }) {
                    self.activeGroupID = storedID
                } else if let taggedGlobal = fetched.first(where: { $0.groupMeta.title == "Tagged Global" }) {
                    self.activeGroupID = taggedGlobal.groupID
                } else {
                    self.activeGroupID = fetched.first?.groupID
                }
            }
    }

    func join(_ group: Group) async {
        guard let groupID = group.id else { return }

        let groupRef = db.collection("Groups").document(groupID)
        let userRef = db.collection("Users").document(userUID)
        let joinedGroupRef = userRef.collection("JoinedGroups").document(groupID)

        do {
            // Add user to group member list
            try await groupRef.updateData([
                "members": FieldValue.arrayUnion([userUID])
            ])

            // Create user-group join record
            var safe = group            // copy
            safe.id = nil               // strip DocumentID
            let meta = try Firestore.Encoder().encode(safe)

            let payload: [String: Any] = [
                "groupMeta": meta,
                "streak": 0,
                "lastPostDate": FieldValue.serverTimestamp(),
                "lastTagWeek": NSNull()
            ]
            try await joinedGroupRef.setData(payload)


            print("✅ User joined group: \(group.title)")
        } catch {
            print("❌ Failed to join group: \(error)")
        }
    }

    deinit {
        listener?.remove()
    }
}

extension GroupsViewModel {

    /// Call immediately after a successful post upload.
    /// Increments streak if this is the first post of the current tag week.
    @MainActor
    func handleStreak(for userUID: String, groupId: String) async {
            print("➡️ handleStreak called for \(groupId) by \(userUID)")
            let db = Firestore.firestore()
            let groupRef  = db.collection("Groups").document(groupId)
            let joinedRef = db.collection("Users")
                              .document(userUID)
                              .collection("JoinedGroups")
                              .document(groupId)
            let userRef   = db.collection("Users").document(userUID)

            do {
                // ── 1. Get the group doc to read nextTagSwitchDate ────────────────
                let groupSnap = try await groupRef.getDocument()
                guard
                    let nextTS  = groupSnap["nextTagSwitchDate"] as? Timestamp
                else {
                    print("⚠️ nextTagSwitchDate missing for \(groupId)")
                    return
                }

                // Current tag-week start = nextTagSwitchDate − 7 days
                let weekStart = startOfTagWeek(from: nextTS.dateValue())

                // ── 2. Read the user’s joined-group doc ───────────────────────────
                let joinedSnap = try await joinedRef.getDocument()
                let lastWeekTS = joinedSnap["lastTagWeek"] as? Timestamp
                let lastWeek   = lastWeekTS?.dateValue()
                print("🧐 lastWeek:", lastWeek ?? "nil",
                      "weekStart:", weekStart)
                // If they already posted this week → no change
                if lastWeek == weekStart {
                    let currentStreak = joinedSnap["streak"] as? Int ?? 0

                    if currentStreak > 0 {
                        try await joinedRef.updateData([
                            "lastPostDate": FieldValue.serverTimestamp(),
                            "lastTagWeek":  Timestamp(date: weekStart)
                        ])
                        print("🟡 same week — no streak change")
                        return
                    }

                    // 🚀 FIRST post of this week → streak goes 0 → 1
                    try await joinedRef.updateData([
                        "streak":       1,
                        "lastPostDate": FieldValue.serverTimestamp(),
                        "lastTagWeek":  Timestamp(date: weekStart),
                        "points":       FieldValue.increment(Int64(2))  // 2 × 1
                    ])
                    
                    print("🔥 Streak for \(groupId) → 1 (+2 pts)")
                    return
                }

                // 🚀 New week rollover
                let oldStreak = joinedSnap["streak"] as? Int ?? 0
                let newStreak = (lastWeek == nil || lastWeek! < weekStart)
                                ? oldStreak + 1 : 1

                try await joinedRef.updateData([
                    "streak":       newStreak,
                    "lastPostDate": FieldValue.serverTimestamp(),
                    "lastTagWeek":  Timestamp(date: weekStart),
                    "points":       FieldValue.increment(Int64(2 * newStreak))  // ✅ correct here
                ])


                print("🔥 Streak for \(groupId) → \(newStreak) (+\(2*newStreak) pts)")
            } catch {
                print("❌ handleStreak error:", error.localizedDescription)
            }
        }




    func startOfTagWeek(from nextSwitch: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return cal.startOfDay(for: nextSwitch.addingTimeInterval(-7 * 86_400))
    }

    /// Call on app launch or every time the user opens a group.
    /// Resets streak to 0 if they missed the current tag week.
    @MainActor
    func resetMissedStreaksIfNeeded() async {
        for joined in myJoinedGroups {
            guard let gid = joined.groupID else { continue }

            let joinedRef = db.collection("Users")
                              .document(userUID)
                              .collection("JoinedGroups")
                              .document(gid)

            do {
                // 1️⃣ Pull group doc for nextTagSwitchDate
                let nextSwitch = try await db.collection("Groups")
                    .document(gid)
                    .getDocument()
                    .get("nextTagSwitchDate") as? Timestamp

                guard let nextSwitch else { continue }
                let weekStart = startOfTagWeek(from: nextSwitch.dateValue())

                // 2️⃣ Has this user missed the week?
                if (joined.lastTagWeek?.dateValue() ?? .distantPast) < weekStart,
                   joined.streak > 0 {

                    // 3️⃣ Read current points from the live snapshot
                    let joinedSnap = try await joinedRef.getDocument()
                    let currentPts = joinedSnap["points"] as? Int ?? 0
                    let penalty    = Int(ceil(Double(currentPts) * 0.20))   // 20 %

                    try await db.runTransaction { txn, _ in
                        txn.updateData([
                            "streak" : 0,
                            "points" : FieldValue.increment(Int64(-penalty))
                        ], forDocument: joinedRef)
                        return nil
                    }

                    print("🔁 \(joined.groupMeta.title): streak → 0, −\(penalty) pts (20%)")
                }

            } catch {
                print("❌ resetMissedStreaks error:", error.localizedDescription)
            }
        }
    }

}
