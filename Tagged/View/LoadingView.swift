import SwiftUI

struct LoadingView: View {
    
    @Binding var show: Bool

    var body: some View {
        ZStack {
            if show {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accentColor.opacity(0.05))
                    .frame(width: 40, height: 40)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.accentColor))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: show)
    }
}
