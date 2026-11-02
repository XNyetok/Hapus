import Foundation

public enum DirectorySize {
    private static let keys: Set<URLResourceKey> = [
        .isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
    ]

    /// Bytes actually allocated on disk for `url`, recursively for folders and packages.
    ///
    /// Symbolic links are never followed. Unreadable items count as zero. Blocking; checks for cancellation.
    public static func allocatedSize(of url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: keys.union([.isDirectoryKey])) else { return 0 }
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        guard
            let enumerator = FileManager.default.enumerator(
                at: url, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in true })
        else { return 0 }

        var total: Int64 = 0
        var visited = 0
        for case let item as URL in enumerator {
            visited += 1
            if visited.isMultiple(of: 512), Task.isCancelled { break }
            guard let values = try? item.resourceValues(forKeys: keys),
                values.isRegularFile == true || values.isSymbolicLink == true
            else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }
}
