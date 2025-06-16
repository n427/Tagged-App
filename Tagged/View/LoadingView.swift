import SwiftUI

// MARK: - LoadingView

// A reusable loading overlay with a centered `ProgressView`
// Displays when `show` is true, with a smooth fade animation.
struct LoadingView: View {
    
    // MARK: - Properties
    
    @Binding var show: Bool

    // MARK: - Body
    
    var body: some View {
        ZStack {
            if show {
                ProgressView()
                    .padding(15)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundColor(Color.accentColor)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: show)
    }
}
