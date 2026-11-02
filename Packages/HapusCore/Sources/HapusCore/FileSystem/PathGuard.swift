import Foundation

/// The last line of defence before Hapus removes anything.
///
/// Every URL that is about to be trashed or deleted goes through ``check(_:allowedRoots:)``.
/// The rules are deliberately conservative: when in doubt, deny.
public struct PathGuard: Sendable {
    public enum Verdict: Hashable, Sendable {
        case allowed
        case denied(Reason)
    }

    public enum Reason: Hashable, Sendable {
        /// Not an absolute `file:` URL.
        case notAFileURL
        /// A location that must never be removed itself, such as the home folder or `~/Documents`.
        case protectedLocation
        /// Inside an area whose contents are never touched, such as iCloud Drive or `/System`.
        case insideProtectedArea
        /// Not strictly inside any of the folders the caller is allowed to clean.
        case outsideAllowedRoots
    }

    /// Fully resolved home folder used for all checks.
    public let home: URL
    private let protectedLocations: Set<[String]>
    private let protectedAreas: [[String]]

    public init(home: URL = .homeDirectory) {
        let home = Self.resolved(home)
        self.home = home

        let homeLocations = [
            "Applications", "Desktop", "Documents", "Downloads", "Library", "Movies", "Music",
            "Pictures", "Public", ".Trash", "Library/Mobile Documents", "Library/CloudStorage",
        ].map { home.appending(path: $0) }
        let systemLocations = [
            "/", "/Applications", "/Library", "/System", "/Users", "/Volumes", "/bin", "/sbin",
            "/usr", "/etc", "/var", "/tmp", "/private", "/opt", "/cores",
        ].map { URL(filePath: $0) }
        protectedLocations = Set(([home] + homeLocations + systemLocations).flatMap(Self.forms))

        let areas =
            ["/System", "/bin", "/sbin", "/usr", "/etc"].map { URL(filePath: $0) }
            + [home.appending(path: "Library/Mobile Documents"), home.appending(path: "Library/CloudStorage")]
        protectedAreas = areas.flatMap(Self.forms)
    }

    /// Decides whether `url` may be removed when the caller is only allowed to clean inside `allowedRoots`.
    public func check(_ url: URL, allowedRoots: [URL]) -> Verdict {
        guard url.isFileURL, url.path(percentEncoded: false).hasPrefix("/") else {
            return .denied(.notAFileURL)
        }
        let target = Self.canonical(url).pathComponents

        if protectedLocations.contains(target) {
            return .denied(.protectedLocation)
        }
        if protectedAreas.contains(where: { Self.isStrictlyInside(target, $0) }) {
            return .denied(.insideProtectedArea)
        }
        let roots = allowedRoots.map { Self.resolved($0).pathComponents }
        guard roots.contains(where: { Self.isStrictlyInside(target, $0) }) else {
            return .denied(.outsideAllowedRoots)
        }
        return .allowed
    }

    // MARK: - Path normalisation

    /// Resolves `.`/`..` and every symlink in the parent folders but keeps the last component as-is,
    /// so a symlink is judged (and removed) as the link itself, never as its destination.
    static func canonical(_ url: URL) -> URL {
        let standardized = url.standardizedFileURL
        guard standardized.pathComponents.count > 1 else { return standardized }
        let parent = resolved(standardized.deletingLastPathComponent())
        return parent.appending(path: standardized.lastPathComponent)
    }

    /// Fully resolves symlinks with `realpath(3)` when the path exists.
    static func resolved(_ url: URL) -> URL {
        let standardized = url.standardizedFileURL
        guard let pointer = realpath(standardized.path(percentEncoded: false), nil) else {
            return standardized
        }
        defer { free(pointer) }
        return URL(filePath: String(cString: pointer))
    }

    /// Both the literal and the fully resolved form, so `/var` and `/private/var` are treated alike.
    private static func forms(_ url: URL) -> [[String]] {
        [url.standardizedFileURL.pathComponents, resolved(url).pathComponents]
    }

    static func isStrictlyInside(_ path: [String], _ root: [String]) -> Bool {
        path.count > root.count && Array(path.prefix(root.count)) == root
    }
}
