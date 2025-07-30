import SwiftUI
import FirebaseFirestore

struct JoinGroupModal: View {
    @Binding var isPresented: Bool
    @ObservedObject var groupsVM: GroupsViewModel

    @State private var groupCode: String = ""
    @State private var isAlreadyJoined = false
    @State private var isGroupFound = false
    @State private var matchedGroup: Group? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 20) {
                Text("Join a Group")
                    .font(.title3)
                    .fontWeight(.semibold)

                TextField("Enter room code", text: $groupCode)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .onChange(of: groupCode) {
                        Task { await checkGroupByCode(code: groupCode) }
                    }

                Button {
                    Task {
                        if let group = matchedGroup, !isAlreadyJoined {
                            await groupsVM.join(group)
                        }
                        isPresented = false
                    }
                } label: {
                    HStack {
                        Image(systemName: isAlreadyJoined ? "checkmark.circle" : "plus")
                        Text(isAlreadyJoined ? "Already Joined" : "Join")
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity)
                    .background(isAlreadyJoined ? Color.gray : Color.accentColor)
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                .disabled(isAlreadyJoined || !isGroupFound)

            }
            .padding(.top, 30)
            .padding(.bottom, 20)
            .background(Color.white)
            .cornerRadius(16)
            .padding(.horizontal, 40)
            .shadow(radius: 10)
        }
    }

    func checkGroupByCode(code: String) async {
        guard !code.trimmingCharacters(in: .whitespaces).isEmpty else {
            matchedGroup = nil
            isGroupFound = false
            isAlreadyJoined = false
            return
        }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("Groups")
                .whereField("roomCode", isEqualTo: code)
                .getDocuments()

            if let doc = snapshot.documents.first,
               let group = try? doc.data(as: Group.self) {
                matchedGroup = group
                isGroupFound = true
                isAlreadyJoined = groupsVM.myJoinedGroups.contains(where: { $0.id == group.id })
            } else {
                matchedGroup = nil
                isGroupFound = false
                isAlreadyJoined = false
            }
        } catch {
        }
    }
}
