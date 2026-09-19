import AppKit

/// The timer used by the menu bar and session surfaces is also the Blocks brand mark.
enum BlocksBrand {
    static func drawMark(in rect: NSRect, color: NSColor) {
        let configuration = NSImage.SymbolConfiguration(pointSize: rect.height, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        guard let symbol = NSImage(systemSymbolName: "timer", accessibilityDescription: "Blocks timer")?
            .withSymbolConfiguration(configuration) else { return }
        let scale = min(rect.width / symbol.size.width, rect.height / symbol.size.height)
        let size = NSSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
        let target = NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                            width: size.width, height: size.height)
        symbol.draw(in: target)
    }

    static let menuIcon: NSImage = {
        let image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Blocks timer")!
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .medium))!
        image.isTemplate = true
        return image
    }()

    static func drawAppIcon(in rect: NSRect) {
        let side = rect.width
        NSColor(calibratedRed: 0.027, green: 0.035, blue: 0.043, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect.insetBy(dx: side * 0.05, dy: side * 0.05),
                     xRadius: side * 0.20, yRadius: side * 0.20).fill()
        drawMark(in: rect.insetBy(dx: side * 0.23, dy: side * 0.23),
                 color: NSColor(calibratedRed: 0.65, green: 0.84, blue: 0.77, alpha: 1))
    }
}
