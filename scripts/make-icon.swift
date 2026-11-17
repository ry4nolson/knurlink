import AppKit

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <output.png>\n".utf8))
    exit(1)
}

let side = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: side,
    pixelsHigh: side,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    exit(1)
}

NSGraphicsContext.current = context
let plate = NSRect(x: 100, y: 100, width: 824, height: 824)
let platePath = NSBezierPath(roundedRect: plate, xRadius: 185, yRadius: 185)
NSGradient(
    starting: NSColor(calibratedRed: 0.20, green: 0.50, blue: 0.98, alpha: 1),
    ending: NSColor(calibratedRed: 0.33, green: 0.25, blue: 0.85, alpha: 1)
)?.draw(in: platePath, angle: -90)

let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 440, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
if let symbol = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: nil)?
    .withSymbolConfiguration(symbolConfiguration) {
    let origin = NSPoint(x: plate.midX - symbol.size.width / 2, y: plate.midY - symbol.size.height / 2)
    symbol.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
}
context.flushGraphics()

guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
