import SwiftUI
import SDWebImageSwiftUI
import FirebaseFirestore

// MARK: - UserSearchView

// Displays a searchable list of all users using Firestore data.
struct UserSearchView: View {

    // MARK: - State

    @State private var searchText = ""
    @State private var allUsers: [User] = []
    @State private var isLoading = true

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Search Bar

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search", text: $searchText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 10)

            // MARK: - Loading Indicator

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {

                // MARK: - User List

                List {
                    ForEach(filteredUsers()) { user in
                        NavigationLink {
                            ReusableProfileContent(user: user, isMyProfile: false)
                        } label: {
                            HStack(spacing: 12) {
                                WebImage(url: user.userProfileURL)
                                    .resizable()
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.username)
                                        .font(.system(size: 15, weight: .semibold))
                                    Text(user.name)
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.plain)
                
                .padding(.top, 15)
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await fetchAllUsers() }
        }
    }

    // MARK: - Filter Logic

    // Filters users based on the current search query.
    func filteredUsers() -> [User] {
        if searchText.isEmpty {
            return allUsers
        } else {
            return allUsers.filter {
                $0.username.lowercased().contains(searchText.lowercased()) ||
                $0.name.lowercased().contains(searchText.lowercased())
            }
        }
    }

    // MARK: - Fetch Users

    // Fetches all user documents from Firestore and decodes them into `User` models.
    func fetchAllUsers() async {
        do {
            let snapshot = try await Firestore.firestore().collection("Users").getDocuments()
            let users = try snapshot.documents.compactMap { doc in
                try doc.data(as: User.self)
            }

            await MainActor.run {
                self.allUsers = users
                self.isLoading = false
            }

        } catch {
            print("Error fetching users: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
