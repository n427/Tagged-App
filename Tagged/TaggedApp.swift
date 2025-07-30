import SwiftUI
import Firebase

@main
struct TaggedApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            SplashRouterView()
        }
    }
}
