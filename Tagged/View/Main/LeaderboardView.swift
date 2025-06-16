import SwiftUI

// MARK: - LeaderboardView

// Displays a leaderboard with a podium view and a ranked list of users.
struct LeaderboardView: View {
    
    let accent = Color.accentColor

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                
                // MARK: - Podium Section

                HStack(alignment: .bottom, spacing: 24) {
                    podiumColumn(rank: 2, height: 100, color: accent.opacity(0.6))
                    podiumColumn(rank: 1, height: 140, color: accent)
                    podiumColumn(rank: 3, height: 80, color: accent.opacity(0.6))
                }
                .padding(.top, 20)

                Divider()
                    .padding(.horizontal, 25)

                // MARK: - Leaderboard Rows

                ScrollView {
                    VStack(spacing: 20) {
                        leaderboardRow(rank: "1", username: "lunaloom", isEliminated: false, streak: 9)
                        leaderboardRow(rank: "2", username: "vxnitycrush", isEliminated: false, streak: 7)
                        leaderboardRow(rank: "3", username: "jamjar.riot", isEliminated: false, streak: 5)
                        leaderboardRow(rank: "X", username: "velvet.arc", isEliminated: true, streak: 0)
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 40)
                }
                .frame(maxHeight: .infinity)
                .refreshable {
                    // Optional: Add refresh logic
                }
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Podium Column

    // Displays a vertical podium column for the top 3 users.
    func podiumColumn(rank: Int, height: CGFloat, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 55, height: 55)
                .clipShape(Circle())

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(color)
                    .frame(width: 65, height: height)

                Text("\(rank)")
                    .font(.system(size: 35, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 6)
            }
        }
    }

    // MARK: - Leaderboard Row

    // Displays a single leaderboard entry row.
    func leaderboardRow(rank: String, username: String, isEliminated: Bool, streak: Int = 5) -> some View {
        HStack(spacing: 12) {
            // Rank
            Text(rank)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(isEliminated ? .red : accent.opacity(0.6))
                .frame(width: 24, alignment: .leading)
                .padding(.leading, 7)

            // Divider
            Rectangle()
                .frame(width: 1, height: 40)
                .foregroundColor(Color.gray.opacity(0.6))

            // Profile image
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 30, height: 30)
                .clipShape(Circle())
                .opacity(isEliminated ? 0.4 : 1)
                .padding(.leading, 7)

            // Username
            Text(username)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(isEliminated ? .gray : .primary)
                .strikethrough(isEliminated, color: .gray)

            Spacer()

            // Streak & Likes
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("🔥")
                    Text("\(streak)")
                        .font(.system(size: 14, weight: .semibold))
                }

                HStack(spacing: 4) {
                    Text("❤️")
                    Text("200")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .opacity(isEliminated ? 0.4 : 1)
            .padding(.trailing, 8)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(isEliminated ? Color.gray.opacity(0.1) : Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(1), lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

struct LeaderboardView_Previews: PreviewProvider {
    static var previews: some View {
        LeaderboardView()
    }
}
