import SwiftUI
import PhotosUI

struct SettingsView: View {
    @Binding var isPresented: Bool

    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var detailedDescription = ""
    @State private var roomCode = ""
    @State private var captions: [String] = [""]

    @State private var selectedImage: UIImage? = nil
    @State private var photoItem: PhotosPickerItem?
    @State private var showImagePicker = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // Group Image
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

                    // Metadata
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Title", text: $groupName).textFieldStyleStyled2()

                        TextField("Description", text: $groupDescription, axis: .vertical)
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
                                ForEach(dummyTags, id: \.self) { tag in
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

                    // Tags editor
                    ReorderableListSection(
                        title: "Tags",
                        items: $captions,
                        placeholder: "Tag",
                        showGenerate: true
                    )
                    .padding(.top, 15)

                    // Save button
                    Button(action: {
                        isPresented = false
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
                }
                .padding(.vertical)
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }

    // Dummy past tags
    var dummyTags: [String] = [
        "Where I procrastinated",
        "Outfit I almost wore",
        "Snack that saved me",
        "My Monday face",
        "Caught in 4K",
        "Dinner I regret",
        "Camera roll surprise",
        "Peak delulu moment"
    ]
}

// Reuse styled text field
extension TextField {
    func textFieldStyleStyled2() -> some View {
        self.padding()
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
            .font(.body)
    }
}
