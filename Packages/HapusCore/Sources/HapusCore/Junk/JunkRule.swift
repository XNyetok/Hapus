import Foundation

/// A place on disk that collects regenerable junk, and how Hapus treats it.
///
/// Built-in rules live in ``JunkRule/catalog``. Read CONTRIBUTING.md before adding one.
public struct JunkRule: Sendable, Hashable, Identifiable {
    public enum ID: String, Sendable, Hashable, CaseIterable {
        // System
        case userCaches, userLogs, mailDownloads, iPhoneSoftwareUpdates, iPadSoftwareUpdates, trash
        // Developer
        case xcodeDerivedData, xcodeArchives, xcodeDeviceSupport, xcodePreviews, simulatorCaches
        case homebrewCache, npmCache, yarnCache, pnpmCache, cocoaPodsCache, swiftPMCache
        case pipCache, goBuildCache, gradleCache, bunCache, cargoRegistryCache
    }

    public enum Group: String, Sendable, Hashable {
        case system, developer
    }

    /// How the contents of the location are presented and removed.
    public enum Strategy: Sendable, Hashable {
        /// Every direct child is its own selectable item, e.g. one folder per app in `~/Library/Caches`.
        case eachChild
        /// All contents form a single selectable item. The folder itself is kept.
        case wholeContents
    }

    /// Whether items start out selected.
    public enum Safety: Sendable, Hashable {
        /// Regenerable data. Selected by default.
        case safe
        /// Probably fine to remove, but the user should look first. Not selected by default.
        case review
    }

    public let id: ID
    public let group: Group
    /// Location relative to the home folder.
    public let relativePath: String
    public let strategy: Strategy
    public let safety: Safety
    public let removal: FileRemover.Method
    /// Direct children that are never offered for removal.
    public let excludedNames: Set<String>
    /// macOS hides this location from apps without Full Disk Access.
    public let needsFullDiskAccess: Bool

    public init(
        id: ID,
        group: Group,
        relativePath: String,
        strategy: Strategy,
        safety: Safety,
        removal: FileRemover.Method = .moveToTrash,
        excludedNames: Set<String> = [],
        needsFullDiskAccess: Bool = false
    ) {
        self.id = id
        self.group = group
        self.relativePath = relativePath
        self.strategy = strategy
        self.safety = safety
        self.removal = removal
        self.excludedNames = excludedNames
        self.needsFullDiskAccess = needsFullDiskAccess
    }

    public func location(in home: URL) -> URL {
        home.appending(path: relativePath, directoryHint: .isDirectory)
    }
}
