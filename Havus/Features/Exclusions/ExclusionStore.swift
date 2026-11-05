import Foundation
import HavusCore
import Observation

/// The files and folders the user told Havus never to touch, kept between launches.
///
/// `RootView` hands the current ``ExclusionList`` to every page: scans leave excluded items out, and every removal
/// passes the list to `PathGuard`, which refuses those items again.
@MainActor
@Observable
final class ExclusionStore {
    /// Sorted by path, as shown in Pengaturan.
    private(set) var urls: [URL]
    private(set) var list: ExclusionList

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let urls = (defaults.stringArray(forKey: Key.paths) ?? []).map { URL(filePath: $0) }
        self.urls = urls
        list = ExclusionList(urls)
    }

    func add(_ newURLs: [URL]) {
        save(urls + newURLs.filter(\.isFileURL))
    }

    func remove(_ removed: Set<URL>) {
        save(urls.filter { !removed.contains($0) })
    }

    /// Drops duplicates, sorts by path and saves.
    private func save(_ candidates: [URL]) {
        var seen: Set<String> = []
        let sorted = candidates.map(Self.path).filter { seen.insert($0).inserted }
            .map { URL(filePath: $0) }
            .sorted { Format.path($0).localizedStandardCompare(Format.path($1)) == .orderedAscending }
        guard sorted != urls else { return }
        urls = sorted
        list = ExclusionList(sorted)
        defaults.set(sorted.map(Self.path), forKey: Key.paths)
    }

    /// Absolute path without a trailing slash, so `/a/b/` and `/a/b` are one entry.
    private static func path(_ url: URL) -> String {
        var path = url.standardizedFileURL.path(percentEncoded: false)
        if path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path
    }

    private enum Key {
        static let paths = "Exclusions.paths"
    }
}
