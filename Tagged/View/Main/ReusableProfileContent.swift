import SwiftUI
import SDWebImageSwiftUI

struct ReusableProfileContent: View {
    var user: User
    var isMyProfile: Bool
    
    var logOutAction: (() -> Void)? = nil
    var deleteAccountAction: (() -> Void)? = nil
    
    @State private var showSettings = false
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    Text(user.username)
                        .font(.system(size: 28, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                        .padding(.bottom, 5)
                        .padding(.horizontal)

                    // Profile header (name + streak + profile image)
                    HStack(alignment: .top, spacing: 16) {
                        WebImage(url: user.userProfileURL)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 8) {
                            Text(user.name)
                                .foregroundColor(.primary)
                                .font(.headline)

                            HStack(spacing: 35) {
                                statView("3", "posts")
                                statView("80", "likes")
                                statView("#4", "rank")
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal)

                    HStack(alignment: .top) {
                        Text("4-week")
                            .foregroundColor(.accentColor)
                            .fontWeight(.semibold)
                        Text(" streak")
                            .foregroundColor(.primary)
                            .fontWeight(.semibold)
                            .padding(.horizontal, -6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    
                    HStack(spacing: 0) {
                        Text(user.userBio)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, -10)

                    // Buttons
                    if isMyProfile {
                        HStack(spacing: 16) {
                            profileButton("Edit Profile") {
                                // Edit profile action
                            }
                            
                            profileButton("Settings") {
                                showSettings.toggle()
                            }
                            
                            .confirmationDialog("Settings", isPresented: $showSettings, titleVisibility: .visible) {
                                Button(role: .none) {
                                    logOutAction?()
                                } label: {
                                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                                Button(role: .destructive) {
                                    deleteAccountAction?()
                                } label: {
                                    Label("Delete Account", systemImage: "trash")
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 5)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                        .padding(.bottom, 5)
                    
                    // Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(0..<30, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                    .padding(.horizontal, 10)
                }
                .padding(.horizontal, 10)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    // MARK: - Subviews

    func statView(_ number: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(number).bold()
            Text(label)
                .font(.footnote)
        }
    }

    func profileButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor, lineWidth: 1)
                )
        }
    }

}
