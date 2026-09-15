import AppKit

/// The single source of geometry for every Blocks brand surface.
/// A simple 18-point silhouette keeps all three blocks distinct in the menu bar.
enum BlocksBrand {
    static func drawMark(in rect: NSRect, color: NSColor) {
        color.setFill()
        let scale = rect.width / 18
        // Three rounded bricks make a compact B with two clear horizontal gaps.
        for (x, y, width, height) in [(1.0, 1.0, 5.0, 16.0), (8.0, 10.0, 9.0, 7.0), (8.0, 1.0, 9.0, 7.0)] {
            NSBezierPath(roundedRect: NSRect(
                x: rect.minX + x * scale, y: rect.minY + y * scale,
                width: width * scale, height: height * scale),
                xRadius: 1.7 * scale, yRadius: 1.7 * scale).fill()
        }
    }

    static let menuIcon: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            drawMark(in: rect, color: .black)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Blocks"
        return image
    }()

    static func drawAppIcon(in rect: NSRect) {
        let side = rect.width
        NSColor(calibratedRed: 0.255, green: 0.286, blue: 0.86, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect.insetBy(dx: side * 0.05, dy: side * 0.05),
                     xRadius: side * 0.20, yRadius: side * 0.20).fill()
        drawMark(in: rect.insetBy(dx: side * 0.19, dy: side * 0.19),
                 color: NSColor(calibratedRed: 0.91, green: 0.90, blue: 1.0, alpha: 1))
    }
}
