import SwiftUI
import FirebaseAuth

struct SplashRouterView: View {
    @AppStorage("log_status") private var logStatus: Bool = false
    @AppStorage("user_UID") private var userUID: String?

    @State private var isLoading = true
    @State private var resolvedUserUID: String? = nil
    @State private var resolvedActiveGroupID: String? = nil
    @State private var groupsVM: GroupsViewModel? = nil

    var body: some View {
        ZStack {
            if isLoading {
                SplashView()
            } else if logStatus,
                      let uid = resolvedUserUID,
                      let vm = groupsVM {
                MainTabContent(userUID: uid, groupsVM: vm)
            } else {
                WelcomeView()
            }
        }
        .onAppear {
            Task { await checkAuthStatus() }
        }
        .onChange(of: logStatus) { _, newStatus in
            if !newStatus {
                resetState()
            } else {
                Task { await checkAuthStatus() }
            }
        }
    }

    private func checkAuthStatus() async {
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        guard let currentUser = Auth.auth().currentUser else {
            await MainActor.run {
                resetState()
                isLoading = false
            }
            return
        }

        do {
            try await currentUser.reload()

            if currentUser.isEmailVerified {
                let uid = currentUser.uid
                let vm = GroupsViewModel(userUID: uid)

                while !vm.hasLoadedGroups {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }

                let activeID = vm.myJoinedGroups
                    .sorted {
                        ($0.lastOpened?.dateValue() ?? .distantPast) >
                        ($1.lastOpened?.dateValue() ?? .distantPast)
                    }
                    .first?.groupID

                await MainActor.run {
                    resolvedUserUID = uid
                    resolvedActiveGroupID = activeID
                    groupsVM = vm
                    isLoading = false
                }
            } else {
                try? Auth.auth().signOut()
                await MainActor.run {
                    resetState()
                    logStatus = false
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                resetState()
                logStatus = false
                isLoading = false
            }
        }
    }

    private func resetState() {
        resolvedUserUID = nil
        resolvedActiveGroupID = nil
        groupsVM = nil
    }
}
