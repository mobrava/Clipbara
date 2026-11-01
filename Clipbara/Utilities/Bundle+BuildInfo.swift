import Foundation

/// Build-specific values from Info.plist, set by the build configuration in
/// project.yml, so the code never decides which build it is. The local Debug build
/// (ClipbaraDev) uses them to stand apart from the installed release.
extension Bundle {
    /// URL schemes declared in `CFBundleURLTypes`, lowercased: `clipbara`, or
    /// `clipbara-dev` for the Debug build (from `CLIPBARA_URL_SCHEME`).
    var urlSchemes: Set<String> {
        /// URL types declared in Info.plist.
        let types = object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        return Set(types.flatMap { ($0["CFBundleURLSchemes"] as? [String] ?? []).map { $0.lowercased() } })
    }
}
