import SwiftUI

struct JoinGroupModal: View {
    @Binding var isPresented: Bool
    @State private var groupCode: String = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            VStack(spacing: 20) {
                Text("Join a Group")
                    .font(.title3)
                    .fontWeight(.semibold)

                TextField("Enter room code", text: $groupCode)
                    .padding(.horizontal)
                    .padding(.vertical, 12) // Increase vertical touch area
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )
                    .padding(.horizontal)

                Button(action: {
                    // 🔁 Handle join logic here
                    isPresented = false
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
            .padding(.vertical, 30)
            .background(Color.white)
            .cornerRadius(16)
            .padding(.horizontal, 40)
            .shadow(radius: 10)
        }
    }
}
