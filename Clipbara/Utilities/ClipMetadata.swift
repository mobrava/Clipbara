import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Facts about a clip that its card footer shows but the clip doesn't store:
/// an image's pixel size and format, a file's size. Each is read once per clip
/// and cached, since cards are redrawn often while the panel scrolls.
@MainActor
enum ClipMetadata {
    /// Pixel size and file format of an image clip.
    struct ImageInfo {
        let pixelWidth: Int
        let pixelHeight: Int
        /// Short format name such as "PNG" or "JPEG", if known.
        let formatName: String?
    }

    /// What a file clip points to on disk.
    enum FileInfo {
        case file(byteCount: Int64)
        case folder
        /// The file was moved or deleted since it was copied.
        case missing
    }

    /// Image facts by clip ID. `nil` values record images that couldn't be read.
    private static var imageInfoCache: [UUID: ImageInfo?] = [:]
    /// File facts by clip ID.
    private static var fileInfoCache: [UUID: FileInfo] = [:]

    /// Reads the image's size and format from its header, without decoding it.
    /// - Parameter item: An image clip.
    static func imageInfo(for item: ClipboardItem) -> ImageInfo? {
        if let cached = imageInfoCache[item.id] {
            return cached
        }
        let info = readImageInfo(from: item.rawData)
        imageInfoCache[item.id] = info
        return info
    }

    /// Looks up the copied file on disk.
    /// - Parameter item: A file clip, whose raw data is its file URL string.
    static func fileInfo(for item: ClipboardItem) -> FileInfo {
        if let cached = fileInfoCache[item.id] {
            return cached
        }
        let info = readFileInfo(from: item.rawData)
        fileInfoCache[item.id] = info
        return info
    }

    /// - Parameter data: Encoded image data (PNG, JPEG, TIFF, HEIC...).
    private static func readImageInfo(from data: Data) -> ImageInfo? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        // EXIF orientations 5–8 are rotated a quarter turn, so the image is
        // shown with width and height swapped.
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let isRotated = (5...8).contains(orientation)
        // Format name from the source's type, e.g. public.png → "PNG".
        let formatName = (CGImageSourceGetType(source) as String?)
            .flatMap { UTType($0)?.preferredFilenameExtension?.uppercased() }
        return ImageInfo(
            pixelWidth: isRotated ? height : width,
            pixelHeight: isRotated ? width : height,
            formatName: formatName
        )
    }

    /// - Parameter data: The clip's raw data, a UTF-8 file URL string.
    private static func readFileInfo(from data: Data) -> FileInfo {
        guard let urlString = String(data: data, encoding: .utf8),
              let url = URL(string: urlString),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return .missing
        }
        if attributes[.type] as? FileAttributeType == .typeDirectory {
            return .folder
        }
        return .file(byteCount: (attributes[.size] as? NSNumber)?.int64Value ?? 0)
    }
}
