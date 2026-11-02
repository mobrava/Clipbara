// Writes sample clips of every type Clipbara recognizes to the clipboard, for
// checking the cards by hand. Each sample is shaped the way ContentTypeClassifier
// reads it, so it lands as the intended type.
//
// Usage:
//   swift scripts/clipboard-samples.swift list
//   swift scripts/clipboard-samples.swift all [--delay 1]
//   swift scripts/clipboard-samples.swift text-long image-png color-light
//
// Clipbara polls the clipboard every 0.5 s, so samples written in one run are
// spaced by --delay seconds (default 1) or only the last one would be kept.
// The source app on the cards is whatever app is in front, usually the terminal.

import AppKit

/// The clipboard the samples are written to. CLIPBOARD_SAMPLES_PASTEBOARD names
/// a private pasteboard instead, for checking the script without touching the
/// real clipboard (or Clipbara's history).
let pasteboard = ProcessInfo.processInfo.environment["CLIPBOARD_SAMPLES_PASTEBOARD"]
    .map { NSPasteboard(name: NSPasteboard.Name($0)) } ?? .general

/// Folder for the generated sample files and folder (file clips point at disk).
let sampleDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("ClipbaraSamples", isDirectory: true)

/// A named sample and how to put it on the clipboard.
struct Sample {
    let name: String
    let summary: String
    let write: () -> Void
}

// MARK: - Helpers

/// Replaces the clipboard with plain text.
/// - Parameter text: The text to copy.
func writeText(_ text: String) {
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

/// Draws a test image: a diagonal gradient with a few shapes, optionally with
/// transparent corners so the card's checkerboard shows through.
/// - Parameters:
///   - width: Pixel width.
///   - height: Pixel height.
///   - transparent: Whether to leave the corners transparent.
/// - Returns: The bitmap, ready to encode.
func makeImage(width: Int, height: Int, transparent: Bool) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    /// Full image area.
    let bounds = NSRect(x: 0, y: 0, width: width, height: height)
    /// Area painted with the gradient; inset leaves transparent corners.
    let paintArea = transparent
        ? NSBezierPath(roundedRect: bounds.insetBy(dx: CGFloat(width) * 0.08, dy: CGFloat(height) * 0.08),
                       xRadius: CGFloat(min(width, height)) * 0.12,
                       yRadius: CGFloat(min(width, height)) * 0.12)
        : NSBezierPath(rect: bounds)
    NSGradient(colors: [.systemTeal, .systemBlue, .systemPurple])!.draw(in: paintArea, angle: 35)
    NSColor.white.withAlphaComponent(0.85).setFill()
    NSBezierPath(ovalIn: NSRect(x: width / 5, y: height / 4, width: width / 4, height: width / 4)).fill()
    NSColor.systemYellow.setFill()
    NSBezierPath(rect: NSRect(x: width * 3 / 5, y: height / 3, width: width / 5, height: height / 3)).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// Replaces the clipboard with encoded image data.
/// - Parameters:
///   - data: PNG or JPEG bytes.
///   - type: The matching pasteboard type.
func writeImage(_ data: Data, type: NSPasteboard.PasteboardType) {
    pasteboard.clearContents()
    pasteboard.setData(data, forType: type)
}

/// Replaces the clipboard with a file URL, as Finder's Copy does.
/// - Parameter url: The file or folder (it need not exist).
func writeFile(_ url: URL) {
    pasteboard.clearContents()
    pasteboard.writeObjects([url as NSURL])
}

/// Replaces the clipboard with a color, as the system color picker does.
/// - Parameter hex: The color as `#RRGGBB`.
func writeColor(_ hex: String) {
    /// Hex digits without the leading `#`, as one number.
    let value = Int(hex.dropFirst(), radix: 16) ?? 0
    let color = NSColor(
        srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: 1
    )
    pasteboard.clearContents()
    pasteboard.writeObjects([color])
}

/// Makes sure the sample file and folder exist.
/// - Returns: The sample file's URL.
@discardableResult
func prepareSampleFiles() -> URL {
    try? FileManager.default.createDirectory(at: sampleDirectory, withIntermediateDirectories: true)
    /// A ~40 KB text file, so the footer shows a real size.
    let file = sampleDirectory.appendingPathComponent("Quarterly Report.txt")
    if !FileManager.default.fileExists(atPath: file.path) {
        let body = String(repeating: "Clipbara sample file line.\n", count: 1500)
        try? body.write(to: file, atomically: true, encoding: .utf8)
    }
    try? FileManager.default.createDirectory(
        at: sampleDirectory.appendingPathComponent("Design Assets", isDirectory: true),
        withIntermediateDirectories: true
    )
    return file
}

// MARK: - Samples

/// Every sample, in the order `all` writes them.
let samples: [Sample] = [
    Sample(name: "text-short", summary: "One short line") {
        writeText("Meeting moved to 3:30 tomorrow.")
    },
    Sample(name: "text-long", summary: "Several paragraphs, to check the body fills and fades") {
        writeText("""
        Clipbara keeps everything you copy, so you can paste it again later.

        Open the panel with the shortcut, pick a card and press Return to paste it into the app you were using. \
        Pin the clips you reuse to a pinboard so they never scroll away.

        Search finds text inside every clip, and filters narrow the list down to one type or a date range. \
        This paragraph is long enough to run past the bottom of the card.
        """)
    },
    Sample(name: "text-code", summary: "Swift code, shown in a monospaced font") {
        writeText("""
        func greet(_ name: String) -> String {
            let greeting = "Hello, \\(name)!"
            return greeting
        }
        """)
    },
    Sample(name: "text-cjk", summary: "Chinese text") {
        writeText("剪贴板历史会保存你复制过的所有内容。打开面板，选择一张卡片，按回车即可粘贴到当前应用。常用的内容可以钉到钉板里，不会被新的记录挤走。")
    },
    Sample(name: "text-huge", summary: "Over 1000 characters, for the 1.2K-style count") {
        writeText(String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 40))
    },
    Sample(name: "rich-text", summary: "RTF with bold and color") {
        /// Styled text: a bold title and a colored phrase.
        let text = NSMutableAttributedString(
            string: "Release notes\n",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 16)]
        )
        text.append(NSAttributedString(
            string: "Cards now use system colors and ",
            attributes: [.font: NSFont.systemFont(ofSize: 13)]
        ))
        text.append(NSAttributedString(
            string: "fill the whole card.",
            attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.systemRed]
        ))
        /// RTF encoding of the styled text.
        let rtf = text.rtf(from: NSRange(location: 0, length: text.length), documentAttributes: [:])!
        pasteboard.clearContents()
        pasteboard.setData(rtf, forType: .rtf)
        pasteboard.setString(text.string, forType: .string)
    },
    Sample(name: "html", summary: "HTML with a plain text fallback") {
        pasteboard.clearContents()
        pasteboard.setString(
            "<h1>Hello</h1><p>This came from a <b>web page</b> with <a href=\"https://apple.com\">a link</a>.</p>",
            forType: .html
        )
        pasteboard.setString("Hello\nThis came from a web page with a link.", forType: .string)
    },
    Sample(name: "url", summary: "A link, as a browser copies it") {
        pasteboard.clearContents()
        pasteboard.writeObjects([NSURL(string: "https://www.apple.com/macos/macos-sequoia/")!])
    },
    Sample(name: "url-long", summary: "A long link with a query string") {
        writeText("https://developer.apple.com/documentation/swiftui/view/scrollclipdisabled(_:)?language=swift&changes=latest_minor#discussion")
    },
    Sample(name: "image-png", summary: "1200×800 PNG with transparent corners") {
        writeImage(makeImage(width: 1200, height: 800, transparent: true).representation(using: .png, properties: [:])!, type: .png)
    },
    Sample(name: "image-jpeg", summary: "1920×1080 JPEG") {
        let jpeg = makeImage(width: 1920, height: 1080, transparent: false)
            .representation(using: .jpeg, properties: [.compressionFactor: 0.8])!
        writeImage(jpeg, type: NSPasteboard.PasteboardType("public.jpeg"))
    },
    Sample(name: "image-tall", summary: "600×1600 PNG, a tall screenshot shape") {
        writeImage(makeImage(width: 600, height: 1600, transparent: false).representation(using: .png, properties: [:])!, type: .png)
    },
    Sample(name: "file", summary: "A ~40 KB text file") {
        writeFile(prepareSampleFiles())
    },
    Sample(name: "folder", summary: "A folder") {
        prepareSampleFiles()
        writeFile(sampleDirectory.appendingPathComponent("Design Assets", isDirectory: true))
    },
    Sample(name: "file-missing", summary: "A file that doesn't exist") {
        writeFile(sampleDirectory.appendingPathComponent("Deleted Draft.pdf"))
    },
    Sample(name: "color-dark", summary: "A dark color, white header text") {
        writeColor("#1E3A8A")
    },
    Sample(name: "color-light", summary: "A light color, dark header text") {
        writeColor("#FDE68A")
    },
]

// MARK: - Command line

/// Arguments after the script name.
var arguments = Array(CommandLine.arguments.dropFirst())
/// Seconds between samples when writing more than one.
var delay: TimeInterval = 1
if let flagIndex = arguments.firstIndex(of: "--delay") {
    guard flagIndex + 1 < arguments.count, let value = TimeInterval(arguments[flagIndex + 1]) else {
        FileHandle.standardError.write(Data("--delay needs a number of seconds\n".utf8))
        exit(1)
    }
    delay = value
    arguments.removeSubrange(flagIndex...(flagIndex + 1))
}

if arguments.isEmpty || arguments == ["list"] {
    print("Samples (pass names, or `all`):")
    for sample in samples {
        print("  \(sample.name.padding(toLength: 14, withPad: " ", startingAt: 0)) \(sample.summary)")
    }
    exit(0)
}

/// Samples to write, in order.
let chosen: [Sample]
if arguments == ["all"] {
    chosen = samples
} else {
    /// Names that don't match a sample.
    let unknown = arguments.filter { name in !samples.contains { $0.name == name } }
    guard unknown.isEmpty else {
        FileHandle.standardError.write(Data("unknown sample: \(unknown.joined(separator: ", ")). Run with `list`.\n".utf8))
        exit(1)
    }
    chosen = arguments.compactMap { name in samples.first { $0.name == name } }
}

for (index, sample) in chosen.enumerated() {
    if index > 0 {
        Thread.sleep(forTimeInterval: delay)
    }
    sample.write()
    print("copied \(sample.name)")
}
