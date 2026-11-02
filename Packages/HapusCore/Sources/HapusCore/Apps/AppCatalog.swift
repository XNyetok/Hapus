import Darwin
import Foundation

public struct InstalledApp: Sendable, Hashable, Identifiable {
    public let url: URL
    /// Name as shown in Finder: the bundle's file name without `.app`.
    public let name: String
    public let bundleIdentifier: String
    /// `CFBundleName`, which apps often use for folders such as `~/Library/Application Support/<name>`.
    public let bundleName: String?
    public let version: String?

    public var id: URL { url }

    public init(url: URL, name: String, bundleIdentifier: String, bundleName: String?, version: String?) {
        self.url = url
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.bundleName = bundleName
        self.version = version
    }
}

/// Lists the apps a user can remove.
public struct AppCatalog: Sendable {
    public let searchRoots: [URL]

    public init(searchRoots: [URL] = AppCatalog.defaultSearchRoots) {
        self.searchRoots = searchRoots
    }

    public static var defaultSearchRoots: [URL] {
        [
            URL(filePath: "/Applications", directoryHint: .isDirectory),
            URL.homeDirectory.appending(path: "Applications", directoryHint: .isDirectory),
        ]
    }

    /// Blocking. Sorted by name. System apps (sealed or SIP-protected) are left out.
    public func installedApps() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        var seen: Set<[String]> = []
        for root in searchRoots {
            collect(in: root, depth: 0, apps: &apps, seen: &seen)
        }
        return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func collect(in folder: URL, depth: Int, apps: inout [InstalledApp], seen: inout Set<[String]>) {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        guard
            let children = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
        else { return }

        for child in children {
            if Task.isCancelled { return }
            let values = try? child.resourceValues(forKeys: keys)
            // e.g. /Applications/Safari.app is a symlink into the sealed system cryptex.
            guard values?.isSymbolicLink != true else { continue }

            if child.pathExtension.lowercased() == "app" {
                guard seen.insert(child.standardizedFileURL.pathComponents).inserted,
                    let app = Self.app(at: child)
                else { continue }
                apps.append(app)
            } else if values?.isDirectory == true, depth < 1 {
                // Vendors often ship apps inside a folder, e.g. /Applications/Adobe Photoshop/.
                collect(in: child, depth: depth + 1, apps: &apps, seen: &seen)
            }
        }
    }

    /// Reads an app bundle. Returns `nil` for anything Hapus must not offer to remove.
    static func app(at url: URL) -> InstalledApp? {
        guard !isProtectedBySystem(url),
            let data = try? Data(contentsOf: url.appending(path: "Contents/Info.plist")),
            let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let identifier = info["CFBundleIdentifier"] as? String, !identifier.isEmpty
        else { return nil }

        return InstalledApp(
            url: url,
            name: url.deletingPathExtension().lastPathComponent,
            bundleIdentifier: identifier,
            bundleName: info["CFBundleName"] as? String,
            version: info["CFBundleShortVersionString"] as? String
        )
    }

    /// System apps live under `/System` or carry the SIP `restricted` flag.
    static func isProtectedBySystem(_ url: URL) -> Bool {
        let components = url.standardizedFileURL.pathComponents
        if components.starts(with: ["/", "System"]) { return true }
        var info = stat()
        let path = "/" + components.dropFirst().joined(separator: "/")
        guard lstat(path, &info) == 0 else { return true }
        return info.st_flags & UInt32(SF_RESTRICTED) != 0
    }
}
