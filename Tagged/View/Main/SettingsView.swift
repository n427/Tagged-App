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
    @State private var deleteError       = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
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
                                    "Ex. The tag should be something that people can base outfits off of. Be specific on what type of fit to create (e.g., New York outfit core, trench coat season, etc).",
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
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Past Tags")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(Array(pastTags.reversed()), id: \.self) { tag in
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
                            showGenerate: true,
                            description: detailedDescription
                        )
                        
                        .padding(.top, 15)
                        let isFormInvalid =
                        isLoading ||
                        title.trimmingCharacters(in: .whitespaces).isEmpty ||
                        description.trimmingCharacters(in: .whitespaces).isEmpty ||
                        detailedDescription.trimmingCharacters(in: .whitespaces).isEmpty ||
                        roomCode.trimmingCharacters(in: .whitespaces).isEmpty ||
                        (selectedImage == nil && groupImageData == nil) ||
                        (queuedTags.first?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
                        Button(action: {
                            Task { await saveGroupChanges() }
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
                        .disableWithOpacity(isFormInvalid)
                        
                        
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Text("Delete Group")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .padding(.vertical, -6)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
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
                    .onAppear {
                        Task {
                            let groupID = groupsVM.activeGroupID ?? ""
                            let rotated = await groupsVM.checkAndUpdateTag(for: groupID)
                            if rotated {
                                try? await Task.sleep(nanoseconds: 500_000_000)
                            }
                            await loadGroupData()
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: isLoading)
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
            
            if isLoading {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.accentColor.opacity(0.05))
                        .frame(width: 40, height: 40)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.accentColor))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        
    }
    
    func deleteGroup() async {
        guard let gid = groupsVM.activeGroupID else { return }
        await MainActor.run { isLoading = true }

        do {
            let db = Firestore.firestore()

            let groupSnap = try await db.collection("Groups").document(gid).getDocument()
            let members   = groupSnap.get("members") as? [String] ?? []
            let imagePath = groupSnap.get("imageURL") as? String ?? ""

            let batch = db.batch()

            for uid in members {
                let joinedRef = db.collection("Users")
                                  .document(uid)
                                  .collection("JoinedGroups")
                                  .document(gid)
                batch.deleteDocument(joinedRef)
            }

            batch.deleteDocument(groupSnap.reference)

            try await batch.commit()

            if let url = URL(string: imagePath),
               let path = Storage.storage().reference(forURL: url.absoluteString).fullPath.split(separator: "/").last {
                try? await Storage.storage()
                       .reference()
                       .child("Group_Images")
                       .child(String(path))
                       .delete()
            }

            await MainActor.run {
                isLoading = false
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                isPresented = false
                dismiss()
            }


        } catch {
            await MainActor.run {
                deleteError = error.localizedDescription
                isLoading   = false
            }
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
                isLoading = false
            }
        }
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
                return
            }
        } catch {
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

            if let image = selectedImage,
               let imageData = image.jpegData(compressionQuality: 0.8) {
                let ref = Storage.storage().reference()
                    .child("Group_Images").child(groupID)
                _ = try await ref.putDataAsync(imageData)
                let downloadURL = try await ref.downloadURL()
                updateData["imageURL"] = downloadURL.absoluteString
            }

            let db = Firestore.firestore()

            try await db.collection("Groups")
                .document(groupID)
                .updateData(updateData)

            var meta: [String: Any] = [:]
            if let t  = updateData["title"]      { meta["groupMeta.title"]  = t }
            if let u  = updateData["imageURL"]   { meta["groupMeta.imageURL"] = u }

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
                batch.updateData(updateData, forDocument: ref)
                batch.updateData(meta,       forDocument: ref)
            }
            try await batch.commit()

            await MainActor.run {
                isLoading = false
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                isPresented = false
                dismiss()
            }


        } catch {
            await MainActor.run { isLoading = false }
        }
    }

}

extension TextField {
    func textFieldStyleStyled2() -> some View {
        self.padding()
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
            .font(.body)
    }
}
