import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppModel.shared.launch()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

/// Every surface Blocks has — the menu bar clock included — is an AppKit window or status item
/// owned by `Surfaces`, so the App has no scene of its own to declare. `Settings` is the empty
/// scene an accessory app can carry without it ever appearing; Blocks's own settings window is
/// opened from the popover.
@main
struct BlocksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}
