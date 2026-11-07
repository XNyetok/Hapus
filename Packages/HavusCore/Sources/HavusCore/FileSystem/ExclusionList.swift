import Foundation

/// Files and folders the user told Havus never to touch.
///
/// An excluded path blocks itself, everything inside it, and every folder that contains it, because removing
/// such a folder would remove the excluded item too. Scanners use ``blocks(_:)`` to leave those items out, and
/// ``PathGuard`` checks it again before every removal.
public struct ExclusionList: Sendable, Hashable {
    /// The excluded paths, as the user chose them.
    public let urls: [URL]
    /// Every excluded path as normalized components, both as given and with symlinks resolved.
    private let keys: [[String]]

    public init(_ urls: [URL] = []) {
        self.urls = urls
        keys = urls.filter(\.isFileURL).flatMap { Self.forms(of: $0, resolving: PathGuard.resolved) }
    }

    public var isEmpty: Bool { keys.isEmpty }

    /// Whether removing `url` would touch an excluded item: `url` is excluded itself, is inside an excluded folder,
    /// or contains an excluded item.
    public func blocks(_ url: URL) -> Bool {
        guard !keys.isEmpty else { return false }
        // `canonical` keeps the last component as-is, like PathGuard, so a symlink is judged as the link itself.
        return Self.forms(of: url, resolving: PathGuard.canonical).contains { target in
            keys.contains { key in target.starts(with: key) || key.starts(with: target) }
        }
    }

    /// Whether `url` is excluded itself or inside an excluded folder. Unlike ``blocks(_:)``, a folder that only holds
    /// an excluded item doesn't count, so a page can mark what the exclusion list protects as a whole.
    public func covers(_ url: URL) -> Bool {
        guard !keys.isEmpty else { return false }
        return Self.forms(of: url, resolving: PathGuard.canonical).contains { target in
            keys.contains { target.starts(with: $0) }
        }
    }

    /// The literal and the resolved form of `url`. Names are compared without regard to case or Unicode
    /// normalization, like on the default APFS volume. Comparing loosely can only block more, never less.
    private static func forms(of url: URL, resolving resolve: (URL) -> URL) -> [[String]] {
        let literal = normalized(url.standardizedFileURL.pathComponents)
        let resolved = normalized(resolve(url).pathComponents)
        return literal == resolved ? [literal] : [literal, resolved]
    }

    private static func normalized(_ components: [String]) -> [String] {
        components.map { $0.precomposedStringWithCanonicalMapping.lowercased() }
    }
}
