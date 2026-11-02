import Foundation

/// Formatting in Indonesian, matching the UI language.
enum Format {
    static let locale = Locale(identifier: "id_ID")

    /// `1234567890` → `1,23 GB`, and `0` → `0 byte` (not "Nol kB").
    static func bytes(_ value: Int64) -> String {
        // Below 1 kB the system's Indonesian format says "bita" (seen on macOS 27), so "0 file dipilih · 0 bita".
        // Use the "byte" everyone says instead.
        guard value >= 1000 else { return String(localized: "\(value) byte") }
        return value.formatted(ByteCountFormatStyle(style: .file, spellsOutZero: false, locale: locale))
    }

    /// Relative date in Indonesian, e.g. `3 bulan yang lalu` ("3 months ago").
    static func relativeDate(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named).locale(locale))
    }

    /// `/Users/someone/Downloads/` → `~/Downloads`
    static func path(_ url: URL) -> String {
        var path = url.path(percentEncoded: false)
        if path.count > 1, path.hasSuffix("/") { path.removeLast() }
        let home = URL.homeDirectory.path(percentEncoded: false)
        return path.hasPrefix(home) ? "~/" + path.dropFirst(home.count) : path
    }
}
