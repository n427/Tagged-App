import SwiftUI
import _PhotosUI_SwiftUI

struct CreateGroupView: View {
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var roomCode = ""
    
    @State private var isPlayMode = true
    @State private var hasPunishment = false
    
    @State private var captions: [String] = [""]
    @State private var punishmentPrompts: [String] = [""]
    @State private var selectedImage: UIImage? = nil
    @State private var photoItem: PhotosPickerItem?
    @State private var showImagePicker = false
    
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Image Picker (Circular Image)
                    VStack(alignment: .leading) {
                        
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
                                        .overlay(Image(systemName: "camera")
                                            .font(.system(size: 30))
                                            .foregroundColor(.gray))
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
                    }
                    .padding(.top, 10)
                    .padding(.horizontal)

                    // Title, Description, Code
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Information")
                            .font(.headline)
                            .padding(.leading, 15)
                        
                        Group {
                            // Group Title
                            TextField("Title", text: $groupName)
                                .padding()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                                )
                                .cornerRadius(10)
                                .font(.body)
                            
                            // Description
                            TextField("Description", text: $groupDescription)
                                .padding()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                                )
                                .cornerRadius(10)
                                .font(.body)
                            
                            // Room Code
                            TextField("Room Code", text: $roomCode)
                                .padding()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                                )
                                .cornerRadius(10)
                                .font(.body)
                        }
                        .padding(.horizontal)

                    }
                    .padding(.vertical)
                    
                    // Mode Toggle
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Game Mode")
                            .font(.headline)
                            .padding(.leading, 15)
                        
                        HStack(spacing: 12) {
                            VStack(spacing: 4) {
                                Button(action: { isPlayMode = true }) {
                                    Text("Play")
                                        .fontWeight(.semibold)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(isPlayMode ? Color.accentColor.opacity(0.7) : Color.white)
                                        .foregroundColor(isPlayMode ? .white : .primary)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                                        )
                                }
                                Text("Private group")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            VStack(spacing: 4) {
                                Button(action: { isPlayMode = false }) {
                                    Text("Explore")
                                        .fontWeight(.semibold)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(!isPlayMode ? Color.accentColor.opacity(0.5) : Color.white)
                                        .foregroundColor(!isPlayMode ? .white : .primary)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                                        )
                                }
                                Text("Public group")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                    }
                    
                    // Punishment Toggle (Play mode only)
                    if isPlayMode {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Punishment")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            HStack(spacing: 12) {
                                ForEach([(false, "No Punishment"), (true, "Punishment")], id: \.0) { value, label in
                                    Button(action: {
                                        hasPunishment = value
                                    }) {
                                        Text(label)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .padding(.vertical, 10)
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                hasPunishment == value ? Color.accentColor.opacity(0.5) : Color.white
                                            )
                                            .foregroundColor(hasPunishment == value ? Color.white : Color.black)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                                            )
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        
                        .padding(.horizontal)
                        .padding(.top, -10)
                        .padding(.bottom, 15)
                    }


                    // Caption Section
                    // MARK: - Caption Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Captions")
                            .font(.headline)
                            .padding(.leading, 15)

                        Text("First one required. More can be added later.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.leading, 15)
                            .padding(.top, -10)

                        ForEach(captions.indices, id: \.self) { i in
                            HStack {
                                TextField("Caption \(i + 1)", text: $captions[i])
                                    .padding()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                                    )
                                    .cornerRadius(10)
                                    .font(.body)

                                if i != 0 {
                                    Button(action: { captions.remove(at: i) }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        HStack {
                            Button(action: { captions.append("") }) {
                                Label("Add", systemImage: "plus")
                                    .font(.subheadline)
                                    .foregroundColor(.accentColor)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                                    )
                            }
                            .padding(.leading, 18)
                            Spacer()
                        }
                    }
                    .padding(.bottom, 15)

                    // MARK: - Punishment Prompts
                    if isPlayMode && hasPunishment {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Punishments")
                                .font(.headline)
                                .padding(.leading, 15)

                            Text("First one required. More can be added later.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.leading, 15)
                                .padding(.top, -10)

                            ForEach(punishmentPrompts.indices, id: \.self) { i in
                                HStack {
                                    TextField("Punishment \(i + 1)", text: $punishmentPrompts[i])
                                        .padding()
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                                        )
                                        .cornerRadius(10)
                                        .font(.body)

                                    if i != 0 {
                                        Button(action: { punishmentPrompts.remove(at: i) }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }

                            HStack {
                                Button(action: { punishmentPrompts.append("") }) {
                                    Label("Add", systemImage: "plus")
                                        .font(.subheadline)
                                        .foregroundColor(.accentColor)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                                        )
                                }
                                
                                .padding(.leading, 18)
                                Spacer()
                            }
                        }
                        
                        .padding(.bottom, 15)
                    }


                    // Submit Button
                    Button(action: {
                        // handle create group
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
            .refreshable{}
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {isPresented = false
}
                }
            }
        }
    }
}
