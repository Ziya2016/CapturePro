import SwiftUI

@main
struct CaptureProApp: App {
    var body: some Scene {
        WindowGroup {
            if ExpiryGuard.isExpired() {
                ExpiredView()
            } else {
                ContentView()
            }
        }
    }
}
