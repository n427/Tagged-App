import SwiftUI

struct PrivacyView: View {
    
    @Binding var path: NavigationPath
    
    let collect = [
        "Your name and email address",
        "Photos you upload to your groups",
        "Group activity (likes, streaks, comments)",
    ]
    let usage = [
        "Power app features like photo sharing, streak tracking, and leaderboards",
        "Help admins manage group content",
        "Improve app functionality and experience"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("What We Collect")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.accentColor)
                Text("We collect limited personal information to make Tagged work as intended, including:")
                    .font(.body)
                BulletList(items: collect)
                Text("We do not collect location data, contacts, or any unnecessary personal information.")
                    .font(.body)
                    .padding(.top, -25)

                Text("How We Use Your Data")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.accentColor)
                Text("We use your data only to:")
                    .font(.body)
                BulletList(items: usage)
                Text("We do not sell your data. Ever.")
                    .font(.body)
                    .padding(.top, -25)
                
                Text("Where It’s Stored")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.accentColor)
                Text("Your data is securely stored using trusted third-party services (e.g., Firebase).")
                    .font(.body)
                Text("We follow best practices to keep your information safe and private.")
                    .font(.body)
                
                Text("How to Delete Your Data")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.accentColor)
                Text("You can delete your account and data at any time by going to your profile settings and selecting “Delete Account.”")
                    .font(.body)
                Text("This will permanently erase your photos, posts, and profile from our system.")
                    .font(.body)
                
                Text("Contact")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.accentColor)
                Text("If you have questions about your privacy, reach out to us at:")
                    .font(.body)
                Link("starttagged@gmail.com", destination: URL(string: "mailto:starttagged@gmail.com")!)
                    .padding(.top, -15)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
    }
}
