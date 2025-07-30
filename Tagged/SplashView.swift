import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Image("tagged_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .opacity(1)
                .padding(.top, -40)
        }
    }
}
