import Foundation

/// `clipbara://` links, so launchers such as Raycast or Alfred can open the
/// panel with their own shortcuts (#7).
///
///     clipbara://open     opens the history panel
///     clipbara://toggle   opens it, or closes it if it is open
///     clipbara://queue    starts or ends the Clip Queue
enum URLCommand: String, CaseIterable {
    case open
    case toggle
    case queue

    /// Reads a command from a link.
    /// - Parameters:
    ///   - url: the link that opened the app
    ///   - schemes: lowercased schemes to accept; defaults to the ones this build
    ///     registers in Info.plist (`clipbara`, or `clipbara-dev` for ClipbaraDev)
    init?(url: URL, schemes: Set<String> = Bundle.main.urlSchemes) {
        // macOS only hands the app links in schemes it registered, so this check is
        // defensive: it keeps parsing in line with the registered schemes.
        guard let scheme = url.scheme?.lowercased(), schemes.contains(scheme) else { return nil }
        // Accept both clipbara://open and clipbara:open.
        // URL.path is empty for clipbara:open on some macOS versions (CI), so
        // read the path from URLComponents.
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let host = components?.host ?? ""
        let path = components?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        let name = host.isEmpty ? path : host
        self.init(rawValue: name.lowercased())
    }
}
