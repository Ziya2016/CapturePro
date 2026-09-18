import SwiftUI

@main
struct CaptureProApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("loggedInUser") private var loggedInUser: String = ""
    @AppStorage("isAdmin") private var isAdmin: Bool = false

    var body: some View {
        Group {
            if isLoggedIn {
                MainView()
            } else {
                LoginView()
            }
        }
    }
}
