import SwiftUI

@main
struct HavusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var permissions = PermissionCenter()
    @State private var updates = UpdateCenter()

    var body: some Scene {
        Window("Havus", id: "main") {
            RootView()
                .environment(permissions)
                .environment(updates)
                .environment(\.locale, Format.locale)
                .frame(minWidth: 860, minHeight: 560)
        }
        .defaultSize(width: 1040, height: 700)
        .windowResizability(.contentMinSize)
        .commands { UpdateCommands(updates: updates) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Havus is a single-window utility: closing the window quits the app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
