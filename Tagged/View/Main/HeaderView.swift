import SwiftUI

// MARK: - HeaderView

// A reusable header with a logo, menu toggle, and search button.
struct HeaderView: View {

    // MARK: - Bindings

    @Binding var showMenu: Bool
    @Binding var showSearch: Bool
    @Binding var showSettings: Bool
    
    var isAdmin: Bool = true

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Logo + Controls Row

            ZStack {
                // Centered App Logo
                Image("tagged_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 30)

                // Left and Right Buttons
                HStack {
                    // Menu Button
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

                    if isAdmin {
                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    // Search Button
                    Button(action: {
                        showSearch = true
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

            // MARK: - Divider

            Divider()
                .background(Color.gray.opacity(0.3))
        }
        .background(Color.white)
    }
}
