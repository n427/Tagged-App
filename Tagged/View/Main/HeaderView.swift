import SwiftUI

struct HeaderView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Hamburger menu icon
                Button(action: {
                    // action here
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.accentColor)
                }

                Spacer()

                // Dropdown-like selector
                Button(action: {
                    // Show dropdown
                }) {
                    HStack(spacing: 5) {
                        Text("Sentinel Grads")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.accentColor)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal, 35)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.accentColor, lineWidth: 1)
                    )
                }

                Spacer()

                // Search icon
                Button(action: {
                    // Search action
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.accentColor)
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
