import SwiftUI
import PhotosUI

// MARK: - RegisterView

struct EditProfileView: View {

    // MARK: - User Input
    @State private var name = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    // MARK: - Profile Picture
    @State private var selectedImage: UIImage? = nil
    @State private var photoItem: PhotosPickerItem?
    @State private var showImagePicker = false
    @State private var userProfilePicData: Data?

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: - Header
                    Text("Edit Profile")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.top, -5)

                    // MARK: - Profile Picture Picker
                    Button(action: {
                        showImagePicker = true
                    }) {
                        ZStack {
                            if let data = userProfilePicData,
                               let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(.systemGray6))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: "camera")
                                            .font(.system(size: 28))
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .photosPicker(isPresented: $showImagePicker, selection: $photoItem)
                    .onChange(of: photoItem) { _, newValue in
                        guard let newValue else { return }
                        Task {
                            if let imageData = try? await newValue.loadTransferable(type: Data.self) {
                                await MainActor.run {
                                    userProfilePicData = imageData
                                }
                            }
                        }
                    }

                    // MARK: - Input Fields
                    Group {
                        TextField("Name (optional)", text: $name)
                            .textInputAutocapitalization(.never)

                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.never)

                        TextField("Bio (optional)", text: $bio)
                            .frame(height: 100, alignment: .top)
                            .textInputAutocapitalization(.never)

                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)

                        SecureField("New Password", text: $password)
                            .textInputAutocapitalization(.never)

                        SecureField("Confirm New Password", text: $confirmPassword)
                            .textInputAutocapitalization(.never)
                    }
                    .padding()
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                    )
                    .padding(.horizontal, 10)

                    // MARK: - Register Button
                    Button(action: {
                        // TODO: Implement registration logic
                    }) {
                        Text("Save Changes")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .fontWeight(.bold)
                            .background(Color.accentColor)
                            .cornerRadius(10)
                    }
                    .disableWithOpacity(
                        userProfilePicData == nil ||
                        username.isEmpty ||
                        email.isEmpty ||
                        password.isEmpty ||
                        confirmPassword != password ||
                        confirmPassword.isEmpty
                    )
                    .padding(.horizontal, 10)

                    Spacer()
                }
                .padding()
            }
        }
        .navigationBarBackButtonHidden(false)
    }
}
