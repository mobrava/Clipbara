import Foundation

/// Build-specific values from Info.plist, set by the build configuration in
/// project.yml, so the code never decides which build it is. The local Debug build
/// (ClipbaraDev) uses them to stand apart from the installed release.
extension Bundle {
    /// The built app name (`CFBundleName`): "ClipbaraDev" for the Debug build,
    /// "Clipbara" otherwise.
    var appName: String {
        object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Clipbara"
    }

    /// Badge next to the menu bar icon (`ClipbaraBuildBadge`, from
    /// `CLIPBARA_BUILD_BADGE`), or nil when the build has none.
    var buildBadge: String? {
        nonEmptyInfoString("ClipbaraBuildBadge")
    }

    /// Text of the orange header at the top of the menu (`ClipbaraBuildBanner`, from
    /// `CLIPBARA_BUILD_BANNER`), or nil when the build has none.
    var buildBanner: String? {
        nonEmptyInfoString("ClipbaraBuildBanner")
    }

    /// URL schemes declared in `CFBundleURLTypes`, lowercased: `clipbara`, or
    /// `clipbara-dev` for the Debug build (from `CLIPBARA_URL_SCHEME`).
    var urlSchemes: Set<String> {
        /// URL types declared in Info.plist.
        let types = object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        return Set(types.flatMap { ($0["CFBundleURLSchemes"] as? [String] ?? []).map { $0.lowercased() } })
    }

    /// Reads an Info.plist string that the build configuration may leave empty.
    /// - Parameter key: Info.plist key
    /// - Returns: the value, or nil when it is missing or empty
    private func nonEmptyInfoString(_ key: String) -> String? {
        /// Raw Info.plist value; empty when the configuration leaves it unset.
        let value = object(forInfoDictionaryKey: key) as? String
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
