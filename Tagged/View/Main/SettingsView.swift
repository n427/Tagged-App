import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseStorage

struct SettingsView: View {
    @Binding var isPresented: Bool

    @State private var title = ""
    @State private var description = ""
    @State private var detailedDescription = ""
    @State private var roomCode = ""
    @State private var isLoading = false

    @AppStorage("user_UID") private var userUID: String = ""
    @ObservedObject var groupsVM: GroupsViewModel

    
    @State private var captions: [String] = [""]

    @State private var selectedImage: UIImage? = nil
    @State private var photoItem: PhotosPickerItem?
    @State private var showImagePicker = false
    @State private var groupImageData: Data? = nil
    
    @State private var currentTag: String = ""
    @State private var queuedTags: [String] = []
    @State private var pastTags: [String] = []
    @State private var showCodeAlert = false

    @State private var showDeleteConfirm = false
    @State private var deleteError       = ""    // optional – surface errors


    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Text("Edit Group")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 5)
                    
                    // Group Image
                    Button(action: { showImagePicker = true }) {
                        ZStack {
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .clipped()
                            } else if let data = groupImageData, let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .clipped()
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Image(systemName: "camera")
                                            .font(.system(size: 30))
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                    }

                    .photosPicker(isPresented: $showImagePicker, selection: $photoItem)
                    .onChange(of: photoItem) { _, newItem in
                        guard let newItem else { return }
                        Task {
                            if let data = try? await newItem.loadTransferable(type: Data.self),
                               let image = UIImage(data: data),
                               let compressedData = image.jpegData(compressionQuality: 0.8),
                               let compressedImage = UIImage(data: compressedData) {
                                
                                await MainActor.run {
                                    selectedImage = compressedImage
                                }
                            }
                        }
                    }

                    // Metadata
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Title", text: $title).textFieldStyleStyled2()

                        TextField("Description", text: $description, axis: .vertical)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                            )
                            .font(.body)
                            .lineLimit(5)

                        TextField("Room Code", text: $roomCode).textFieldStyleStyled2()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Detailed Description")
                                .font(.headline)
                                .fontWeight(.semibold)

                            Text("For Tag generation purposes. Not shown publicly.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.vertical, 4)

                            TextField(
                                "Describe your theme & audience in detail",
                                text: $detailedDescription,
                                axis: .vertical
                            )
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                            )
                            .font(.body)
                            .lineLimit(5)
                        }
                        .padding(.top, 25)
                    }
                    .padding(.horizontal)

                    // Past Tags section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Past Tags")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(pastTags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundColor(.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                    .padding(.bottom, 10)

                    // Tags editor
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current Tag")
                            .font(.headline)
                            .padding(.horizontal)

                        Text(currentTag.isEmpty ? "No current tag" : currentTag)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor.opacity(1), lineWidth: 1)
                            )
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }

                    
                    ReorderableListSection(
                        title: "Tags",
                        items: $queuedTags,
                        placeholder: "Tag",
                        showGenerate: true
                    )
                    .padding(.top, 15)

                    // Save button
                    Button(action: {
                        Task {
                                await saveGroupChanges()
                            }
                        }) {
                        Text("Save Settings")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    .disableWithOpacity(
                        isLoading ||
                        title.trimmingCharacters(in: .whitespaces).isEmpty ||
                        description.trimmingCharacters(in: .whitespaces).isEmpty ||
                        detailedDescription.trimmingCharacters(in: .whitespaces).isEmpty ||
                        roomCode.trimmingCharacters(in: .whitespaces).isEmpty ||
                        (selectedImage == nil && groupImageData == nil) ||
                        queuedTags.first?.trimmingCharacters(in: .whitespaces).isEmpty ?? true
                    )
                    
                    // ⬇️ place this right under the “Save Settings” button ─────────────
                    Button(role: .destructive) {       // ⇠ shows a red outline automatically
                        showDeleteConfirm = true        // ⇠ new @State flag (add it below)
                    } label: {
                        Text("Delete Group")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .padding(.vertical, -6)
                    }
                    .buttonStyle(.bordered)             // red outline & text
                    .tint(.red)                         // make sure it’s red
                    .padding(.horizontal)

                    .alert("Delete Group?",
                           isPresented: $showDeleteConfirm,
                           actions: {
                               Button("Cancel", role: .cancel) {}
                               Button("Delete", role: .destructive) {
                                   Task { await deleteGroup() }
                               }
                           },
                           message: {
                               Text("This will permanently remove the group for all members.")
                           })


                }
                .padding(.vertical)
                .overlay {
                    if isLoading {
                        ProgressView()
                    }
                }
                .onAppear {
                    Task { await loadGroupData(); await checkAndUpdateTag(for: groupsVM.activeGroupID ?? "") }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .alert("Room Code Already Exists",
                   isPresented: $showCodeAlert,
                   actions: { Button("OK", role: .cancel) { } },
                   message: { Text("Please choose a different room code.") })

        }
        
    }
    
    /// Completely removes the group document, its storage image, and every
    /// member’s mirror in `JoinedGroups`.
    func deleteGroup() async {
        guard let gid = groupsVM.activeGroupID else { return }
        await MainActor.run { isLoading = true }

        do {
            let db = Firestore.firestore()

            // 1️⃣ fetch member uid list + image ref (if any)
            let groupSnap = try await db.collection("Groups").document(gid).getDocument()
            let members   = groupSnap.get("members") as? [String] ?? []
            let imagePath = groupSnap.get("imageURL") as? String ?? ""

            // 2️⃣ start a batch
            let batch = db.batch()

            // remove mirror from every user
            for uid in members {
                let joinedRef = db.collection("Users")
                                  .document(uid)
                                  .collection("JoinedGroups")
                                  .document(gid)
                batch.deleteDocument(joinedRef)
            }

            // delete main group doc
            batch.deleteDocument(groupSnap.reference)

            try await batch.commit()

            // 3️⃣ delete Storage-side image (ignore errors)
            if let url = URL(string: imagePath),
               let path = Storage.storage().reference(forURL: url.absoluteString).fullPath.split(separator: "/").last {
                try? await Storage.storage()
                       .reference()
                       .child("Group_Images")
                       .child(String(path))
                       .delete()
            }

            // 4️⃣ UI cleanup
            await MainActor.run {
                isLoading = false
                isPresented = false                      // close editor
                Task {
                    await groupsVM.refreshJoinedGroups()
                }                 // tell VM to reload
            }

        } catch {
            await MainActor.run {
                deleteError = error.localizedDescription
                isLoading   = false
            }
            print("❌ deleteGroup:", error)
        }
    }

    func loadGroupData() async {
        guard let groupID = groupsVM.activeGroupID else { return }

        await MainActor.run { isLoading = true }

        do {
            let doc = try await Firestore.firestore().collection("Groups").document(groupID).getDocument()

            if let data = doc.data() {
                let imageURLString = data["imageURL"] as? String
                var imageData: Data? = nil

                if let urlString = imageURLString, let url = URL(string: urlString) {
                    let (fetchedData, _) = try await URLSession.shared.data(from: url)
                    imageData = fetchedData
                }

                await MainActor.run {
                    title = data["title"] as? String ?? ""
                    description = data["description"] as? String ?? ""
                    detailedDescription = data["detailedDescription"] as? String ?? ""
                    roomCode = data["roomCode"] as? String ?? ""
                    
                    currentTag = data["currentTag"] as? String ?? ""
                    queuedTags = data["queuedTags"] as? [String] ?? []
                    pastTags = data["pastTags"] as? [String] ?? []

                    groupImageData = imageData

                    // Only set selectedImage if it hasn’t been set already (e.g., user hasn’t picked one)
                    if selectedImage == nil,
                       let imageData,
                       let uiImage = UIImage(data: imageData) {
                        selectedImage = uiImage
                    }


                    isLoading = false
                }
            }

        } catch {
            await MainActor.run {
                print("❌ Failed to load group data: \(error.localizedDescription)")
                isLoading = false
            }
        }
    }

    func checkAndUpdateTag(for groupID: String) async {
        let groupRef = Firestore.firestore().collection("Groups").document(groupID)

        do {
            let doc = try await groupRef.getDocument()
            guard var data = doc.data() else {
                print("No data in document.")
                return
            }

            let current = data["currentTag"] as? String
            var past = data["pastTags"] as? [String] ?? []
            var queued = data["queuedTags"] as? [String] ?? []
            let nextDate = (data["nextTagSwitchDate"] as? Timestamp)?.dateValue() ?? .distantFuture

            print("⏱️ Now: \(Date())")
            print("⏰ Next switch: \(nextDate)")
            print("🔥 Current: \(current ?? "nil"), Queued: \(queued), Past: \(past)")

            if Date() >= nextDate {
                if let current {
                    if current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        past.insert("No tag set", at: 0)
                    } else {
                        past.insert(current, at: 0)
                    }
                }

                let newCurrent = queued.isEmpty ? nil : queued.removeFirst()
                let nextSwitchDate = getNextSunday1159pmPST()

                var updates: [String: Any] = [
                    "pastTags": past,
                    "queuedTags": queued,
                    "nextTagSwitchDate": Timestamp(date: nextSwitchDate)
                ]
                updates["currentTag"] = (newCurrent?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
                    ? "No tag set"
                    : newCurrent!

                print("✅ Updating tags: \(updates)")
                try await groupRef.updateData(updates)
            } else {
                print("🛑 Not time yet — no update.")
            }

        } catch {
            print("❌ Error in tag rotation: \(error)")
        }
    }


    
    func getNextSunday1159pmPST() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        let now = Date()
        let nextSunday = calendar.nextDate(after: now, matching: DateComponents(weekday: 1), matchingPolicy: .nextTime)!
        return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: nextSunday)!
    }

    
    func saveGroupChanges() async {
        guard let groupID = groupsVM.activeGroupID else { return }
        do {
            let snap = try await Firestore.firestore()
                .collection("Groups")
                .whereField("roomCode", isEqualTo: roomCode)
                .limit(to: 1)
                .getDocuments()

            if let doc = snap.documents.first, doc.documentID != groupID {
                await MainActor.run {
                    showCodeAlert = true
                    isLoading = false
                }
                return                                      // ⬅︎ stop — duplicate code
            }
        } catch {
            print("❌ room-code check failed:", error.localizedDescription)
        }
        await MainActor.run { isLoading = true }

        do {
            var updateData: [String: Any] = [
                "title": title,
                "description": description,
                "detailedDescription": detailedDescription,
                "roomCode": roomCode,
                "queuedTags": queuedTags
            ]

            // 1️⃣ upload image if changed
            if let image = selectedImage,
               let imageData = image.jpegData(compressionQuality: 0.8) {
                let ref = Storage.storage().reference()
                    .child("Group_Images").child(groupID)
                _ = try await ref.putDataAsync(imageData)
                let downloadURL = try await ref.downloadURL()
                updateData["imageURL"] = downloadURL.absoluteString
            }

            let db = Firestore.firestore()

            // 2️⃣ update main Groups doc
            try await db.collection("Groups")
                .document(groupID)
                .updateData(updateData)

            // 3️⃣ build the groupMeta mirror payload
            var meta: [String: Any] = [:]
            if let t  = updateData["title"]      { meta["groupMeta.title"]  = t }
            if let u  = updateData["imageURL"]   { meta["groupMeta.imageURL"] = u }

            // 4️⃣ batch-update every member’s JoinedGroups mirror
            let memberIDs = try await db.collection("Groups")
                .document(groupID)
                .getDocument()
                .get("members") as? [String] ?? []

            let batch = db.batch()
            for uid in memberIDs {
                let ref = db.collection("Users")
                    .document(uid)
                    .collection("JoinedGroups")
                    .document(groupID)
                batch.updateData(updateData, forDocument: ref)        // top-level
                batch.updateData(meta,       forDocument: ref)        // 👈 groupMeta.*
            }
            try await batch.commit()

            await MainActor.run { isLoading = false
                isPresented = false}

        } catch {
            print("❌ saveGroupChanges:", error.localizedDescription)
            await MainActor.run { isLoading = false }
        }
    }

}

// Reuse styled text field
extension TextField {
    func textFieldStyleStyled2() -> some View {
        self.padding()
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
            .font(.body)
    }
}
