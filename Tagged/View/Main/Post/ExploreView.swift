import SwiftUI
import SDWebImageSwiftUI // For loading images efficiently from URLs
import Firebase // For interacting with Firestore or Firebase features

// MARK: - ExploreView: Displays a scrollable grid of posts using ReusablePostContent
struct ExploreView: View {
    @Binding var posts: [Post]

    var body: some View {
        VStack(spacing: 0) {
            
            ReusablePostContent(posts: $posts)
            
            // Full-width gray line
            Rectangle()
                .fill(Color.gray.opacity(0.5))
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)


            // Tag bar content
            VStack(alignment: .leading, spacing: 2) {
                Text("This Week's Tag:")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .padding(.bottom, 6)

                Text("“Caught lacking in public”")
                    .font(.system(size: 15))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 11)
            .padding(.bottom, 15)
            .background(Color.white)
        }

        .ignoresSafeArea(edges: .bottom)
    }
}
