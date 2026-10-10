import SwiftUI

@main
struct MouseClickerApp: App {
    @StateObject private var clicker = Clicker()

    var body: some Scene {
        WindowGroup("MouseClicker") {
            ContentView()
                .environmentObject(clicker)
                .frame(width: 360)
        }
        .windowResizability(.contentSize)
    }
}
