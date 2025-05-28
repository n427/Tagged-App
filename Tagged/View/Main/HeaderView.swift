import SwiftUI

struct HeaderView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Hamburger menu
                Button(action: {
                    // action here
                }) {
                    VStack(spacing: 4) {
                        ForEach(0..<3) { _ in
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: 20, height: 2)
                        }
                    }
                }
                .padding(.horizontal, 5)
                
                Spacer()
                
                // Dropdown-like middle button
                Button(action: {
                    // Show dropdown here
                }) {
                    HStack(spacing: 5) {
                        Text("Sentinel Grads")
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .font(.system(size: 10))
                            .padding(.horizontal, 40)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(.accentColor)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.accentColor, lineWidth: 1)
                    )
                }
                
                Spacer()
                
                // Search icon
                Button(action: {
                    // Search action here
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 0.5)
                .edgesIgnoringSafeArea(.horizontal)
        }
        .padding(.top, 0)
    }
}

struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {
        HeaderView()
    }
}
