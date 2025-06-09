import SwiftUI

struct HeaderView: View {
    @Binding var showMenu: Bool
    @Binding var showSearch: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Image("tagged_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 30)

                HStack {
                    Button(action: {
                        withAnimation {
                            showMenu.toggle()
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.accentColor)
                    }

                    Spacer()

                    Button(action: {
                        showSearch = true // 👈 Toggle search from parent
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 12)
            .padding(.bottom, 20)

            Divider()
                .background(Color.gray.opacity(0.3))
        }
        .background(Color.white)
    }
}

