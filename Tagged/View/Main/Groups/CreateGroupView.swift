import SwiftUI
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore
import PhotosUI

struct CreateGroupView: View {
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var detailedDescription = ""
    @State private var roomCode = ""

    @State private var isPlayMode = true
    @State private var hasPunishment = false

    @State private var captions: [String] = [""]

    @State private var photoItem: PhotosPickerItem?
    @State private var showImagePicker = false
    @State private var groupPicData: Data?

    @Binding var isPresented: Bool
    
    @State private var showCodeAlert = false
    @State private var isSaving      = false
    
    @ObservedObject var groupsVM: GroupsViewModel


    var body: some View {
        ZStack {
            NavigationView {
                ScrollView {
                    VStack(spacing: 20) {
                        
                        Button(action: {
                            showImagePicker = true
                        }) {
                            ZStack {
                                if let groupPicData,
                                   let image = UIImage(data: groupPicData) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
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
                        .onChange(of: photoItem) { _, newValue in
                            guard let newValue else { return }
                            Task {
                                do {
                                    guard let imageData = try await newValue.loadTransferable(type: Data.self) else { return }
                                    await MainActor.run {
                                        groupPicData = imageData
                                    }
                                } catch {
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Information").font(.headline)
                            
                            TextField("Title", text: $groupName).textFieldStyleStyled()
                            TextField(
                                "Description",
                                text: $groupDescription,
                                axis: .vertical
                            )
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                            )
                            .font(.body)
                            .lineLimit(5)
                            
                            TextField("Room Code", text: $roomCode).textFieldStyleStyled()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Detailed Description")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("For Tag generation purposes. Not shown publicly.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 4)
                                
                                Text("Ex. 'The tag should be something that people can base outfits off of. Be specific on what type of fit to create (e.g., New York outfit core, trench coat season, etc).'")
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
                        
                        GroupModeSelector(isPlayMode: $isPlayMode)
                            .padding(.top, 15)
                        
                        ReorderableListSection(
                            title: "Tags",
                            items: $captions,
                            placeholder: "Tag",
                            showGenerate: true,
                            description: detailedDescription
                        )
                        
                        .padding(.top, 15)
                        
                        Button(action: { Task { await checkAndCreateGroup() } }) {
                            Text(isSaving ? "Saving…" : "Create Group")
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.accentColor)
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                        .disableWithOpacity(isSaving || groupPicData == nil
                                  || groupName.isEmpty || groupDescription.isEmpty
                                  || roomCode.isEmpty
                                  || (captions.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true))
                    }
                    .padding(.vertical)
                }
                .alert("Room Code Already Exists",
                       isPresented: $showCodeAlert,
                       actions: { Button("OK", role: .cancel) { } },
                       message: { Text("Please choose a different room code.") })
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("Create Group")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isPresented = false }
                    }
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: isSaving)
        }
        if isSaving {
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
    
    func checkAndCreateGroup() async {
        isSaving = true

        do {
            let snap = try await Firestore.firestore()
                .collection("Groups")
                .whereField("roomCode", isEqualTo: roomCode)
                .limit(to: 1)
                .getDocuments()

            if !snap.isEmpty {
                await MainActor.run {
                    isSaving = false
                    showCodeAlert = true
                }
                return
            }

            createGroup()

        } catch {
            isSaving = false
        }
    }

    func createGroup() {
        guard let user = Auth.auth().currentUser else { return }
        let userUID = user.uid

        Task {
            var imageURLString = ""

            if let data = groupPicData {
                let ref = Storage.storage().reference()
                    .child("Group_Images/\(UUID().uuidString).jpg")
                _ = try? await ref.putDataAsync(data)
                imageURLString = (try? await ref.downloadURL().absoluteString) ?? ""
            }

            let trimmed        = captions.map { $0.trimmingCharacters(in: .whitespaces) }
                                         .filter { !$0.isEmpty }
            let currentTag     = trimmed.first ?? "No tag set"
            let queuedTags     = Array(trimmed.dropFirst())
            let nextSwitchDate = Timestamp(date: getNextSunday1159pmPST())

            let groupData: [String: Any] = [
                "title":              groupName,
                "description":        groupDescription,
                "detailedDescription":detailedDescription,
                "roomCode":           roomCode,
                "isPlayMode":         isPlayMode,
                "hasPunishment":      hasPunishment,
                "imageURL":           imageURLString,
                "createdBy":          userUID,
                "createdAt":          Timestamp(date: Date()),
                "adminID":            userUID,
                "members":            [userUID],

                "currentTag":         currentTag,
                "queuedTags":         queuedTags,
                "pastTags":           [],
                "nextTagSwitchDate":  nextSwitchDate
            ]

            do {
                let groupRef = try await Firestore.firestore()
                    .collection("Groups")
                    .addDocument(data: groupData)
                let groupID = groupRef.documentID

                let joinedRef = Firestore.firestore()
                    .collection("Users")
                    .document(userUID)
                    .collection("JoinedGroups")
                    .document(groupID)

                let snapshot = try await groupRef.getDocument()
                if let meta = try? snapshot.data(as: Group.self) {
                    let encodedMeta = try Firestore.Encoder().encode(meta)

                    let joinedData: [String: Any] = [
                        "groupMeta":    encodedMeta,
                        "streak":       0,
                        "points":       0,
                        "lastPostDate": FieldValue.serverTimestamp(),
                        "lastTagWeek":  NSNull(),
                        "lastOpened":   FieldValue.serverTimestamp()
                    ]
                    try await joinedRef.setData(joinedData)
                }

                await MainActor.run {
                    groupsVM.activeGroupID = groupID
                    isPresented = false
                }

            } catch {
            }
        }
    }

    func getNextSunday1159pmPST() -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = Date()
        let nextSun = cal.nextDate(after: now, matching: DateComponents(weekday: 1),
                                   matchingPolicy: .nextTime)!
        return cal.date(bySettingHour: 23, minute: 59, second: 0, of: nextSun)!
    }
}

extension TextField {
    func textFieldStyleStyled() -> some View {
        self.padding()
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
            .font(.body)
    }
}

struct ReorderableListSection: View {
    let title: String
    @Binding var items: [String]
    let placeholder: String
    let showGenerate: Bool
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).padding(.leading)

            Text("First one required. More can be added later.")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.leading)
                .padding(.top, -6)

            ForEach(Array(items.enumerated()), id: \.offset) { index, _ in
                HStack {
                    TextField("\(placeholder) \(index + 1)", text: Binding(
                        get: { items[index] },
                        set: { items[index] = $0 }
                    ))
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.5)))

                    if index != 0 {
                        Button(action: {
                            if index < items.count {
                                items.remove(at: index)
                            }
                        }) {
                            Image(systemName: "trash").foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal)
            }

            HStack {
                Button(action: { items.append("") }) {
                    Label("Add", systemImage: "plus")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.5)))
                }

                if showGenerate {
                    Button(action: {
                        Task {
                            do {
                                var newTag = try await ChatGPTService().generateTag(description: description, existingTags: items)
                                var attempts = 0
                                while items.contains(newTag) && attempts < 5 {
                                    newTag = try await ChatGPTService().generateTag(description: description, existingTags: items)
                                    attempts += 1
                                }
                                await MainActor.run {
                                    items.append(newTag)
                                }
                            } catch {
                                await MainActor.run {
                                    items.append("Error generating")
                                }
                            }
                        }
                    }) {
                        Label("Generate", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.5)))
                    }
                }


                Spacer()
            }
            .padding(.leading)
        }
        .padding(.bottom)
    }
}

struct GroupModeSelector: View {
    @Binding var isPlayMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Game Mode").font(.headline).padding(.leading)
                .padding(.vertical, -4)
            
            Text("Play mode groups are private and require a code to join. Explore mode groups are public and discoverable in search")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.leading)

            HStack(spacing: 12) {
                let modes = [(true, "Play"), (false, "Explore")]

                ForEach(modes, id: \.1) { (value, label) in
                    Button(action: { isPlayMode = value }) {
                        Text(label)
                            .fontWeight(.semibold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isPlayMode == value ? Color.accentColor.opacity(0.7) : Color.white)
                            .foregroundColor(isPlayMode == value ? .white : .primary)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.5)))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct PunishmentToggle: View {
    @Binding var hasPunishment: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Getting Tagged")
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.leading)
            
            Text("Enable/disable making users who break their streaks lose 20% of their points")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.leading)
                .padding(.vertical, -2)
            
            HStack(spacing: 12) {
                let modes = [(true, "Enable"), (false, "Disable")]
                
                ForEach(modes, id: \.1) { (value, label) in
                    Button(action: { hasPunishment = value }) {
                        Text(label)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(hasPunishment == value ? Color.accentColor.opacity(0.5) : Color.white)
                            .foregroundColor(hasPunishment == value ? .white : .primary)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.5)))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
