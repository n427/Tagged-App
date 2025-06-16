import SwiftUI

// MARK: - JoinGroupModal
// A modal overlay for joining a group using a room code
struct JoinGroupModal: View {
    @Binding var isPresented: Bool // Controls whether the modal is shown
    @State private var groupCode: String = "" // User-entered group code

    var body: some View {
        ZStack {
            // MARK: - Background Dim Layer
            Color.black.opacity(0.3) // Semi-transparent black background
                .ignoresSafeArea() // Extends behind safe area edges
                .onTapGesture {
                    isPresented = false // Dismiss when background is tapped
                }

            // MARK: - Modal Content
            VStack(spacing: 20) {
                // Title
                Text("Join a Group")
                    .font(.title3)
                    .fontWeight(.semibold)

                // MARK: - TextField for Group Code
                TextField("Enter room code", text: $groupCode)
                    .padding(.horizontal)
                    .padding(.vertical, 12) // Better touch area
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )
                    .padding(.horizontal)

                // MARK: - Join Button
                Button(action: {
                    // Handle join logic here
                    isPresented = false // Dismiss modal after tap
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .semibold))
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                        .padding(.horizontal)
                }

            }
            .padding(.top, 30)
            .padding(.bottom, 20)
            .background(Color.white) // Modal background
            .cornerRadius(16)
            .padding(.horizontal, 40) // Horizontal inset from screen edges
            .shadow(radius: 10) // Soft shadow for elevation
        }
    }
}
