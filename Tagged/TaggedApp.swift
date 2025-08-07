import SwiftUI
import Firebase

@main
struct TaggedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    var delegate: AppDelegate
    @AppStorage("log_status") var logStatus: Bool = false
    @AppStorage("has_seen_walkthrough") var hasSeenWalkthrough: Bool = false
    
    var body: some Scene {
        WindowGroup {
           if logStatus {
               if hasSeenWalkthrough {
                   SplashRouterView()
               } else {
                   WalkthroughView()
               }
           } else {
               SplashRouterView()
           }
       }
    }
}
