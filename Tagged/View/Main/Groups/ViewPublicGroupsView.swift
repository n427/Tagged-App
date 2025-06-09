import SwiftUI

struct PublicGroup: Identifiable {
    let id = UUID()
    let imageName: String
    let name: String
    let description: String
}

struct ViewPublicGroupsView: View {
    @State private var searchText = ""
    
    @Binding var isPresented: Bool

    // Dummy data
    let groups: [PublicGroup] = [
        PublicGroup(imageName: "photo", name: "Photography Club", description: "Weekly photo prompts"),
        PublicGroup(imageName: "photo", name: "Study Buddies", description: "Focus accountability group group group group group group group group group group group group "),
        PublicGroup(imageName: "photo", name: "Art Prompts", description: "Share your art each week")
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search for a group", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)

                // Group list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(groups.filter {
                            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
                        }) { group in
                            HStack(alignment: .top, spacing: 12) {
                                // Image block
                                ZStack {
                                    Color.gray.opacity(0.1)
                                    Image(systemName: "camera")
                                        .font(.system(size: 24))
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 60, height: 60)
                                .cornerRadius(6)

                                // Name and description
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(group.name)
                                        .font(.headline)
                                    Text(group.description)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .fixedSize(horizontal: false, vertical: true) // allows auto-wrap and height expansion
                                }

                                Spacer()

                                // Join button, vertically centered
                                VStack {
                                    Spacer()
                                    Button("Join") {
                                        isPresented = false
                                    }
                                    .font(.subheadline)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    Spacer()
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable{}
            }
            .navigationTitle("Public Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
