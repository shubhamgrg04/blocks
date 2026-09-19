import AppKit

// Append to Brand.swift and run with Swift to export the shared native timer mark.
let markPixels = 1024
let markBitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: markPixels, pixelsHigh: markPixels,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: markBitmap)
BlocksBrand.drawMark(in: NSRect(x: 80, y: 80, width: 864, height: 864),
    color: NSColor(calibratedRed: 0.65, green: 0.84, blue: 0.77, alpha: 1))
NSGraphicsContext.restoreGraphicsState()
try markBitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
