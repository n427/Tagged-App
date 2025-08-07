import SwiftUI

struct WalkthroughView: View {
    @AppStorage("has_seen_walkthrough") private var hasSeenWalkthrough = false
    @State private var currentIndex = 0

    private let pages = [
        ("welcome_1", "Welcome to Tagged", "Stay Consistent with Your Crew", "Every week, a new Tag drops. You and your group post a photo to match it. Miss a week? You get Tagged (and lose 20% of your pointrs)."),
        ("welcome_2", "One Photo. Once a Week.", "Post Every Week to Keep Your Streak", "Everyone in your group has the same Tag. You have from Monday to Sunday to post, or you'll face the consequences."),
        ("welcome_3", "Don’t Get Tagged", "Miss a Post, Break Your Streak, Lose Your Points", "Keep your streak alive to climb the leaderboard. Get Tagged and you might sink to the bottom."),
        ("welcome_4", "Save the Memories", "Look Back at Your Favorite Moments", "Tagged turns your posts into a Yearbook of moments so you can relive each week whenver."),
        ("welcome_5", "Explore. Compete. Create", "Play Your Way", "Join public groups, create private rooms, and spice it up with punishments. Tagged is yours to make.")
    ]

    var body: some View {
        VStack {
            TabView(selection: $currentIndex) {
                ForEach(0..<pages.count, id: \.self) { index in
                    VStack {
                        Spacer(minLength: 30)

                        Text(pages[index].1)
                            .font(.title.bold())
                            .foregroundColor(.accentColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Spacer(minLength: 10)

                        Image(pages[index].0)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 350)
                            .padding(.horizontal)

                        Spacer(minLength: 10)

                        Text(pages[index].2)
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Text(pages[index].3)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                            .padding(.top, 4)

                        Spacer(minLength: 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 20)
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))

            HStack {
                if currentIndex < pages.count - 1 {
                    Button("Skip") {
                        hasSeenWalkthrough = true
                    }
                    .padding(.leading, 5)
                    .foregroundColor(.gray)
                }

                Spacer()

                Button(action: {
                    if currentIndex < pages.count - 1 {
                        withAnimation {
                            currentIndex += 1
                        }
                    } else {
                        hasSeenWalkthrough = true
                    }
                }) {
                    Text(currentIndex == pages.count - 1 ? "Let's Play!" : "Continue")
                        .padding()
                        .frame(maxWidth: 160)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.trailing, 5)
            }
            .padding(.horizontal)
            .padding(.top, 10)
        }
    }
}
