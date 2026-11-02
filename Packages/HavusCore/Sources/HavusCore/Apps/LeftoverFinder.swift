import Foundation

/// A file or folder an app left behind in `~/Library`.
public struct Leftover: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Hashable, CaseIterable {
        case applicationSupport, caches, preferences, containers, groupContainers, savedState
        case logs, httpStorage, webKit, cookies, launchAgents, applicationScripts
    }

    public enum Match: Sendable, Hashable {
        /// Named after the app's bundle identifier. Reliable, selected by default.
        case bundleIdentifier
        /// Named after the app's name. Probably right, but the user should check first.
        case appName
    }

    public let url: URL
    public let kind: Kind
    public let match: Match
    public let size: Int64

    public var id: URL { url }
}

/// Finds data an app keeps in the user's Library, so it can be removed together with the app.
public struct LeftoverFinder: Sendable {
    struct Location: Sendable {
        let kind: Leftover.Kind
        let relativePath: String
        /// Whether a folder named exactly like the app counts. Only where apps really do that.
        let matchesAppName: Bool
    }

    static let locations: [Location] = [
        Location(kind: .applicationSupport, relativePath: "Library/Application Support", matchesAppName: true),
        Location(kind: .caches, relativePath: "Library/Caches", matchesAppName: true),
        Location(kind: .preferences, relativePath: "Library/Preferences", matchesAppName: false),
        Location(kind: .preferences, relativePath: "Library/Preferences/ByHost", matchesAppName: false),
        Location(kind: .containers, relativePath: "Library/Containers", matchesAppName: false),
        Location(kind: .groupContainers, relativePath: "Library/Group Containers", matchesAppName: false),
        Location(kind: .savedState, relativePath: "Library/Saved Application State", matchesAppName: false),
        Location(kind: .logs, relativePath: "Library/Logs", matchesAppName: true),
        Location(kind: .httpStorage, relativePath: "Library/HTTPStorages", matchesAppName: false),
        Location(kind: .webKit, relativePath: "Library/WebKit", matchesAppName: false),
        Location(kind: .cookies, relativePath: "Library/Cookies", matchesAppName: false),
        Location(kind: .launchAgents, relativePath: "Library/LaunchAgents", matchesAppName: false),
        Location(kind: .applicationScripts, relativePath: "Library/Application Scripts", matchesAppName: false),
    ]

    /// Folder names too generic to ever match an app by name.
    static let genericNames: Set<String> = [
        "apple", "google", "microsoft", "adobe", "mozilla", "jetbrains", "cache", "caches", "logs", "data",
        "helper", "updater",
    ]

    public let home: URL

    public init(home: URL = .homeDirectory) {
        self.home = home
    }

    /// Every folder results can come from. Pass these to ``FileRemover`` as allowed roots.
    public var searchRoots: [URL] {
        Self.locations.map { home.appending(path: $0.relativePath, directoryHint: .isDirectory) }
    }

    /// Blocking.
    /// - Parameter otherBundleIdentifiers: IDs of the other installed apps, so their data is never claimed.
    public func leftovers(for app: InstalledApp, otherBundleIdentifiers: Set<String> = []) -> [Leftover] {
        let bundleID = app.bundleIdentifier.lowercased()
        let others = otherBundleIdentifiers.map { $0.lowercased() }.filter { $0.count > bundleID.count }
        let names = Self.nameCandidates(for: app)
        var results: [Leftover] = []
        var seen: Set<[String]> = []

        for location in Self.locations {
            if Task.isCancelled { break }
            let folder = home.appending(path: location.relativePath, directoryHint: .isDirectory)
            guard
                let children = try? FileManager.default.contentsOfDirectory(
                    at: folder, includingPropertiesForKeys: nil, options: [])
            else { continue }

            for child in children {
                let name = child.lastPathComponent.lowercased()
                let match: Leftover.Match
                if Self.matches(name, bundleID: bundleID, kind: location.kind),
                    !others.contains(where: { Self.matches(name, bundleID: $0, kind: location.kind) })
                {
                    match = .bundleIdentifier
                } else if location.matchesAppName, names.contains(name) {
                    match = .appName
                } else {
                    continue
                }
                guard seen.insert(child.pathComponents).inserted else { continue }
                results.append(
                    Leftover(
                        url: child, kind: location.kind, match: match,
                        size: DirectorySize.allocatedSize(of: child)))
            }
        }
        return results
    }

    static func matches(_ name: String, bundleID: String, kind: Leftover.Kind) -> Bool {
        if name == bundleID || name.hasPrefix(bundleID + ".") { return true }
        // Group containers are named "<team ID>.<bundle ID>" or "group.<bundle ID>".
        return kind == .groupContainers && name.hasSuffix("." + bundleID)
    }

    static func nameCandidates(for app: InstalledApp) -> Set<String> {
        // Apple's apps use names (Mail, Music, …) that collide with system folders.
        guard !app.bundleIdentifier.lowercased().hasPrefix("com.apple.") else { return [] }
        let names = [app.name, app.bundleName]
            .compactMap { $0?.lowercased() }
            .filter { $0.count >= 3 && !genericNames.contains($0) }
        return Set(names)
    }
}
