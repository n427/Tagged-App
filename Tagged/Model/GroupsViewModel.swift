import SwiftUI
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class GroupsViewModel: ObservableObject {
    @Published var myJoinedGroups: [JoinedGroup] = []

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()
    private let userUID: String
    @Published var hasLoadedGroups = false


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
        Task {
            await refreshJoinedGroups()
        }
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

            if let activeID = self.activeGroupID {
                _ = await checkAndUpdateTag(for: activeID)
            }
        } catch {
        }
    }

    @MainActor
    func checkAndUpdateTag(for groupID: String) async -> Bool {

        let groupRef = Firestore.firestore().collection("Groups").document(groupID)
        do {
            let doc = try await groupRef.getDocument()
            guard let data = doc.data() else {
                return false
            }

            let current = data["currentTag"] as? String ?? ""
            var past = data["pastTags"] as? [String] ?? []
            var queued = data["queuedTags"] as? [String] ?? []
            let nextDate = (data["nextTagSwitchDate"] as? Timestamp)?.dateValue() ?? .distantFuture

            guard Date() >= nextDate else {
                return false
            }

            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            past.insert(trimmed.isEmpty ? "No Tag Set" : trimmed, at: 0)

            let newCurrent = queued.isEmpty ? "No Tag Set" : queued.removeFirst()
            let nextSwitchDate = getNextSunday1159pmPST()

            let updates: [String: Any] = [
                "currentTag": newCurrent,
                "pastTags": past,
                "queuedTags": queued,
                "nextTagSwitchDate": Timestamp(date: nextSwitchDate)
            ]

            try await groupRef.updateData(updates)

            await resetMissedStreaksIfNeeded()
            return true
        } catch {
            return false
        }
    }

    
    @MainActor
    func fetchStreaks() async {
        do {
            let snap = try await db.collection("Users")
                .document(userUID)
                .collection("JoinedGroups")
                .getDocuments()

            let updated = try snap.documents.compactMap { doc -> JoinedGroup? in
                var joined = try doc.data(as: JoinedGroup.self)
                joined.id = doc.documentID
                return joined
            }

            self.myJoinedGroups = updated

        } catch {
        }
    }

    
    func getNextSunday1159pmPST() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        let now = Date()
        let nextSunday = calendar.nextDate(after: now, matching: DateComponents(weekday: 1), matchingPolicy: .nextTime)!
        return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: nextSunday)!
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
                        joined.id = doc.documentID
                        fetched.append(joined)
                    } catch {
                    }
                }


                self.myJoinedGroups = fetched
                self.hasLoadedGroups = true
                
                if let storedID = self.storedActiveGroupID,
                   fetched.contains(where: { $0.groupID == storedID }) {
                    self.activeGroupID = storedID
                } else if let taggedGlobal = fetched.first(where: { $0.groupMeta.title == "Tagged Global" }) {
                    self.activeGroupID = taggedGlobal.groupID
                } else if let fallback = fetched.first?.groupID {
                    self.activeGroupID = fallback
                } else {
                    self.activeGroupID = nil
                }
            }
    }

    func join(_ group: Group) async {
        guard let groupID = group.id else { return }

        let groupRef = db.collection("Groups").document(groupID)
        let userRef = db.collection("Users").document(userUID)
        let joinedGroupRef = userRef.collection("JoinedGroups").document(groupID)

        do {
            try await groupRef.updateData([
                "members": FieldValue.arrayUnion([userUID])
            ])

            var safe = group
            safe.id = nil
            let meta = try Firestore.Encoder().encode(safe)

            let payload: [String: Any] = [
                "groupMeta": meta,
                "streak": 0,
                "lastPostDate": FieldValue.serverTimestamp(),
                "lastTagWeek": NSNull(),
                "lastOpened":   FieldValue.serverTimestamp()
            ]
            try await joinedGroupRef.setData(payload)

            await MainActor.run {
                self.activeGroupID = groupID
            }

        } catch {
        }
    }

    deinit {
        listener?.remove()
    }
}

extension GroupsViewModel {
    @MainActor
    func reset() {
        listener?.remove()
        listener = nil
        myJoinedGroups = []
        activeGroupID = nil
        hasLoadedGroups = false
    }

    
    func leave(groupID: String, userUID: String) async {
        let db = Firestore.firestore()
        let groupRef = db.collection("Groups").document(groupID)
        let userRef = db.collection("Users").document(userUID)
        let joinedRef = userRef.collection("JoinedGroups").document(groupID)

        do {
            try await groupRef.updateData([
                "members": FieldValue.arrayRemove([userUID])
            ])

            let postSnap = try await db.collection("Posts")
                .whereField("userUID", isEqualTo: userUID)
                .whereField("groupID", isEqualTo: groupID)
                .getDocuments()

            for doc in postSnap.documents {
                try await doc.reference.delete()
            }

            try await joinedRef.delete()


            await refreshJoinedGroups()

            if let first = myJoinedGroups.first {
                self.activeGroupID = first.groupID
            } else {
                self.activeGroupID = nil
            }

        } catch {
        }
    }

    @MainActor
    func handleStreak(for userUID: String, groupId: String) async {
            let db = Firestore.firestore()
            let groupRef  = db.collection("Groups").document(groupId)
            let joinedRef = db.collection("Users")
                              .document(userUID)
                              .collection("JoinedGroups")
                              .document(groupId)
        _   = db.collection("Users").document(userUID)

            do {
                let groupSnap = try await groupRef.getDocument()
                guard
                    let nextTS  = groupSnap["nextTagSwitchDate"] as? Timestamp
                else {
                    return
                }

                let weekStart = startOfTagWeek(from: nextTS.dateValue())

                let joinedSnap = try await joinedRef.getDocument()
                let lastWeekTS = joinedSnap["lastTagWeek"] as? Timestamp
                let lastWeek   = lastWeekTS?.dateValue()
                if lastWeek == weekStart {
                    let currentStreak = joinedSnap["streak"] as? Int ?? 0

                    if currentStreak > 0 {
                        try await joinedRef.updateData([
                            "lastPostDate": FieldValue.serverTimestamp(),
                            "lastTagWeek":  Timestamp(date: weekStart)
                        ])
                        return
                    }

                    try await joinedRef.updateData([
                        "streak":       1,
                        "lastPostDate": FieldValue.serverTimestamp(),
                        "lastTagWeek":  Timestamp(date: weekStart),
                        "points":       FieldValue.increment(Int64(2))
                    ])
                    
                    return
                }

                let oldStreak = joinedSnap["streak"] as? Int ?? 0
                let newStreak = (lastWeek == nil || lastWeek! < weekStart)
                                ? oldStreak + 1 : 1

                try await joinedRef.updateData([
                    "streak":       newStreak,
                    "lastPostDate": FieldValue.serverTimestamp(),
                    "lastTagWeek":  Timestamp(date: weekStart),
                    "points":       FieldValue.increment(Int64(2 * newStreak))
                ])


            } catch {
            }
        }




    func startOfTagWeek(from nextSwitch: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return cal.startOfDay(for: nextSwitch.addingTimeInterval(-7 * 86_400))
    }

    @MainActor
    func resetMissedStreaksIfNeeded() async {
        for joined in myJoinedGroups {
            guard let gid = joined.groupID else {
                continue
            }

            let joinedRef = db.collection("Users")
                .document(userUID)
                .collection("JoinedGroups")
                .document(gid)

            do {
                let groupDoc = try await db.collection("Groups").document(gid).getDocument()
                guard let nextSwitch = groupDoc["nextTagSwitchDate"] as? Timestamp else {
                    continue
                }

                let weekStart = startOfTagWeek(from: nextSwitch.dateValue())

                let joinedSnap = try await joinedRef.getDocument()
                let firestoreLastTagWeek = (joinedSnap["lastTagWeek"] as? Timestamp)?.dateValue() ?? .distantPast
                let firestoreStreak = joinedSnap["streak"] as? Int ?? 0
                let currentPts = joinedSnap["points"] as? Int ?? 0

                if firestoreLastTagWeek < weekStart, firestoreStreak > 0 {
                    let penalty = Int(ceil(Double(currentPts) * 0.20))

                    _ = try await db.runTransaction { txn, _ in
                        txn.updateData([
                            "streak": 0,
                            "points": FieldValue.increment(Int64(-penalty))
                        ], forDocument: joinedRef)
                        return nil
                    }

                } else {
                }

            } catch {
            }
        }
    }


}
