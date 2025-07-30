import SwiftUI

enum AppRoute: Hashable {
    case login
    case register
    case howToPlay
    case privacyPolicy
    case help
    case resetPassword
    case home
}

struct WelcomeView: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 30) {
                
                Spacer()
                
                
                Image("tagged_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                
                Spacer()
                

                Button(action: {
                    path.append(AppRoute.login)
                }) {
                    Text("Login")
                        .frame(maxWidth: 200)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .fontWeight(.bold)
                }
                .contentShape(Rectangle())
                .padding(.horizontal)
                .padding(.bottom, 20)

                Button(action: {
                    path.append(AppRoute.register)
                }) {
                    Text("Register")
                        .frame(maxWidth: 200)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .fontWeight(.bold)
                }
                .contentShape(Rectangle())
                .padding(.horizontal)
                .padding(.bottom, 20)

                Button(action: {
                    path.append(AppRoute.howToPlay)
                }) {
                    Text("How to Play")
                        .frame(maxWidth: 200)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.accentColor, lineWidth: 1)
                        )
                        .foregroundColor(.accentColor)
                        .fontWeight(.bold)
                }
                .contentShape(Rectangle())
                .padding(.horizontal)

                Spacer()


                HStack {
                    Button("\(Image(systemName: "info.circle")) Privacy Policy") {
                        path.append(AppRoute.privacyPolicy)
                    }
                    .padding(.horizontal, 15)

                    Spacer()

                    Button("\(Image(systemName: "questionmark.circle")) Help") {
                        path.append(AppRoute.help)
                    }
                    .padding(.horizontal, 15)
                }
                .font(.footnote)
                .padding(.horizontal)
                .padding(.bottom, 20)


                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .login:
                        LoginView(path: $path)
                    case .register:
                        RegisterView(path: $path)
                    case .home:
                        Text("Home")
                            .font(.largeTitle)
                            .bold()
                    case .privacyPolicy:
                        PrivacyView(path: $path)
                    case .help:
                        HelpView(path: $path)
                    case .howToPlay:
                        InstructionsView(path: $path)
                    case .resetPassword:
                        Text("Reset Password")
                            .font(.largeTitle)
                            .bold()
                    }
                }
            }
        }
    }
}


struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
    }
}


extension View {
    
    func disableWithOpacity(_ condition: Bool) -> some View {
        self
            .disabled(condition)
            .opacity(condition ? 0.6 : 1)
    }
    
    func closeKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
