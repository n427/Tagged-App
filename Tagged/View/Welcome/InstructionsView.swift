import SwiftUI

struct InstructionsView: View {
    
    @Binding var path: NavigationPath
    
    let joiningGame = [
            "Make your own group or join an existing one.",
            "Play Mode: Private, friend-based groups",
            "Explore Mode: Public, interest-based groups where anyone can join",
            "Each group has an admin who sets the weekly Tag (caption prompt) and keeps things on track."
    ]
    let weeklyTag = [
        "Every group gets a new Tag at the start of the week - a short, photo-friendly prompt like:",
        "“Weirdest place I ate this week” or “Outfit I almost wore”",
        "Admins can either write a new Tag each week or generate one using AI."
    ]
    let submitPhoto = [
        "You have a week from every Sunday to post a photo that matches the weekly Tag."
    ]
    let likeReact = [
        "As submissions come in, scroll through the week’s entries and like your favorites.",
        "The more likes you get, the higher you climb on the Leaderboard.",
        "You can also comment on posts to hype your friends up."
    ]
    let getTagged = [
        "If you miss the deadline, you’ll get Tagged: losing 20% of your total points.",
        "Your streak resets as well"
    ]
    let yearbook = [
        "Every group has a Yearbook: a scrollable archive of all the photos ever posted.",
        "No more digging through chats or DMs to find that one cursed pic, it’s all saved, week by week"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Join or Start a Group")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.accentColor)
                BulletList(items: joiningGame)

                Text("Weekly Tags")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.accentColor)
                BulletList(items: weeklyTag)

                Text("Submit Your Photo")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.accentColor)
                BulletList(items: submitPhoto)
                
                Text("Like & Comment")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.accentColor)
                BulletList(items: likeReact)
                
                Text("Getting Tagged")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.accentColor)
                BulletList(items: getTagged)
                
                Text("Yearbook")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.accentColor)
                BulletList(items: yearbook)
            }
            .padding()
        }
        .navigationBarBackButtonHidden(false)
    }
}

struct BulletList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .font(.body)
                    Text(item)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .padding(.top, -25)
    }
}

struct InstructionsView_Previews: PreviewProvider {
    @State static var path = NavigationPath()

    static var previews: some View {
        InstructionsView(path: $path)
    }
}
