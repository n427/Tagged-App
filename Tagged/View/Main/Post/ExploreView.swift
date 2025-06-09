import SwiftUI
import SDWebImageSwiftUI
import Firebase

struct ExploreView: View {
    @Binding var posts: [Post]

    var body: some View {
        ReusablePostContent(posts: $posts)
    }
}
