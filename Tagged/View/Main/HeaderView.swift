import SwiftUI

struct HeaderView: View {

    @Binding var showMenu: Bool
    @Binding var showSearch: Bool
    @Binding var showSettings: Bool
    @State private var showLeaveAlert = false

    
    var isAdmin: Bool = true
    var onLeave: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Image("tagged_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 30)

                HStack {
                    Button(action: {
                        withAnimation {
                            showMenu.toggle()
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.accentColor)
                    }

                    Spacer()

                    if isAdmin {
                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.accentColor)
                        }
                    } else if onLeave != nil {
                        Button(action: {
                            showLeaveAlert = true
                        }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }

                    Button(action: {
                        showSearch = true
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 12)
            .padding(.bottom, 20)

            Divider()
                .background(Color.gray.opacity(0.3))
        }
        
        .background(Color.white)
        .alert("Are you sure you want to leave?", isPresented: $showLeaveAlert) {
            Button("Yes, Leave Group", role: .destructive) {
                onLeave?()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action will delete all your posts and your streak.")
        }

    }
}
