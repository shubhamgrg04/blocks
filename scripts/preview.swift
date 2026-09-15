import AppKit
import SwiftUI

@main enum Preview {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let model = AppModel()
        let output = URL(fileURLWithPath: "Resources/Previews")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        func render<V: View>(_ name: String, _ view: V, width: CGFloat, height: CGFloat, dark: Bool = false) throws {
            let host = NSHostingView(rootView: view.environment(\.colorScheme, dark ? .dark : .light))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            window.contentView = host
            host.frame = NSRect(x: 0, y: 0, width: width, height: height)
            host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
            let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
        }
        try render("menu", MenuView(model: model), width: 380, height: 655)
        try render("menu-dark", MenuView(model: model), width: 380, height: 655, dark: true)
        try render("review", ReviewView(model: model), width: 800, height: 1000)
        try render("review-archive", ReviewView(model: model, tab: .archive), width: 800, height: 600)
        try render("settings", SettingsView(model: model), width: 560, height: 600)
        try render("capture", PromptView(model: model, kind: .capture, close: {}), width: 520, height: 260)
        try render("intent", PromptView(model: model, kind: .intent, close: {}), width: 520, height: 420)
        try render("queue", PromptView(model: model, kind: .queue, close: {}), width: 520, height: 260)
        try render("pause", PromptView(model: model, kind: .pause, close: {}), width: 520, height: 330)
        try render("abandon", PromptView(model: model, kind: .abandon, close: {}), width: 520, height: 260)
        try render("settings-dark", SettingsView(model: model), width: 560, height: 600, dark: true)
        model.start("Shape the next chapter of Blocks")
        try render("running", MenuView(model: model), width: 380, height: 670)
        try render("check", TakeoverView(model: model), width: 900, height: 420)
        model.stop("A short interruption")
        try render("paused", MenuView(model: model), width: 380, height: 720)
        print("Rendered fourteen design previews")
    }
}
