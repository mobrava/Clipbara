// Builds AppIcon-Dev (the ClipbaraDev icon) from AppIcon: the 1024 px icon with an
// orange "DEV" badge near its bottom edge. Writes only the 1024 px image; the
// smaller sizes are scaled from it by scripts/make-dev-icon.sh.
//
// Usage: swift scripts/make-dev-icon.swift <source 1024.png> <output 1024.png>

import AppKit

/// Command-line arguments: source and output PNG paths.
let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: make-dev-icon.swift <source.png> <output.png>\n".utf8))
    exit(1)
}
/// Source icon (AppIcon 1024 px).
let sourceURL = URL(fileURLWithPath: arguments[1])
/// Where the badged icon is written.
let outputURL = URL(fileURLWithPath: arguments[2])

/// Canvas size in pixels; the badge geometry below is in this space (origin bottom-left).
let side = 1024
guard
    let source = NSImage(contentsOf: sourceURL),
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ),
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
else {
    FileHandle.standardError.write(Data("cannot read \(sourceURL.path)\n".utf8))
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

// The original icon, unchanged.
source.draw(in: NSRect(x: 0, y: 0, width: side, height: side))

// Badge: a pill near the bottom of the icon body (a rounded square spanning about
// 100–924). The badge, its rim and its shadow must all stay inside that shape: if
// anything sticks out, macOS 26 treats the icon as non-standard and shrinks it onto
// a grey plate.
/// Badge frame: wide enough to read at 32 px, clear of the body's rounded corners.
let badge = NSRect(x: 262, y: 140, width: 500, height: 170)
/// Fully rounded ends.
let badgePath = NSBezierPath(roundedRect: badge, xRadius: badge.height / 2, yRadius: badge.height / 2)

// Soft shadow so the badge lifts off the blue body, like the cards in the icon.
NSGraphicsContext.saveGraphicsState()
/// Drop shadow under the badge.
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowOffset = NSSize(width: 0, height: -6)
shadow.shadowBlurRadius = 16
shadow.set()
NSColor(srgbRed: 1.0, green: 0.55, blue: 0.0, alpha: 1).setFill()
badgePath.fill()
NSGraphicsContext.restoreGraphicsState()

// White rim separates the badge from the card and the blue body behind it.
NSColor.white.setStroke()
badgePath.lineWidth = 10
badgePath.stroke()

// "DEV", centred in the badge.
/// Badge label attributes.
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 128, weight: .black),
    .foregroundColor: NSColor.white,
    .kern: 6,
]
/// The badge label.
let label = NSAttributedString(string: "DEV", attributes: attributes)
/// Label size, to centre it.
let labelSize = label.size()
label.draw(at: NSPoint(x: badge.midX - labelSize.width / 2, y: badge.midY - labelSize.height / 2))

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: outputURL)
