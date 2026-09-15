import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppModel.shared.launch()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct BlocksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel.shared
    var body: some Scene {
        MenuBarExtra {
            MenuView(model: model)
        } label: {
            Label {
                Text(model.state.phase == .running || model.state.phase == .paused ? model.clock : "Blocks")
            } icon: {
                Image(nsImage: BlocksBrand.menuIcon)
            }

        }.menuBarExtraStyle(.window)
    }
}
