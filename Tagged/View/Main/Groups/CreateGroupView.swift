import SwiftUI
import PhotosUI

// MARK: - View for creating a new group, including metadata and game mode selection.
struct CreateGroupView: View {
    // Group input fields
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var detailedDescription = ""
    @State private var roomCode = ""

    // Game mode toggle
    @State private var isPlayMode = true
    // Punishment toggle
    @State private var hasPunishment = false

    // Caption list
    @State private var captions: [String] = [""]

    // Image selection
    @State private var selectedImage: UIImage? = nil
    @State private var photoItem: PhotosPickerItem?
    @State private var showImagePicker = false

    // View dismissal binding
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // Group image selection
                    Button(action: { showImagePicker = true }) {
                        ZStack {
                            if let selectedImage {
                                Image(uiImage: selectedImage)
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
                    .onChange(of: photoItem) { _, newItem in
                        guard let newItem else { return }
                        Task {
                            if let data = try? await newItem.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                selectedImage = image
                            }
                        }
                    }

                    // Group metadata input
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

                    // Game mode toggle (Play / Explore)
                    GroupModeSelector(isPlayMode: $isPlayMode)
                        .padding(.top, 15)

                    // Punishment toggle (only shown in Play mode)
                    if isPlayMode {
                        PunishmentToggle(hasPunishment: $hasPunishment)
                    }

                    // Caption list with reordering and optional generation
                    ReorderableListSection(
                        title: "Tags",
                        items: $captions,
                        placeholder: "Tag",
                        showGenerate: true
                    )
                    
                    .padding(.top, 15)

                    // Submit button
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Create Group")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}

// Custom text field styling
extension TextField {
    func textFieldStyleStyled() -> some View {
        self.padding()
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
            .font(.body)
    }
}

// MARK: - Reusable list for editable and reorderable caption inputs
struct ReorderableListSection: View {
    let title: String
    @Binding var items: [String]
    let placeholder: String
    let showGenerate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).padding(.leading)

            Text("First one required. More can be added later.")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.leading)
                .padding(.top, -6)

            ForEach(items.indices, id: \.self) { i in
                HStack {
                    TextField("\(placeholder) \(i + 1)", text: $items[i])
                        .padding()
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.5)))

                    if i != 0 {
                        Button(action: { items.remove(at: i) }) {
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
                    Button(action: { /* Placeholder for generate logic */ }) {
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

// MARK: - Toggle between "Play" and "Explore" group modes
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

// MARK: - Toggle for enabling or disabling punishments in Play mode
struct PunishmentToggle: View {
    @Binding var hasPunishment: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Getting Tagged")
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.leading)
            
            Text("Enable/disable making users who break their streaks hidden for a week and lose 20% of their points")
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
