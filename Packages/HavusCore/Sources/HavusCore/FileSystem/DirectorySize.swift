import Foundation
import os

public enum DirectorySize {
    /// How much space something takes, and whether Havus could read all of it.
    public struct Measurement: Sendable, Hashable {
        /// Bytes allocated on disk for everything Havus could read.
        public let bytes: Int64
        /// `false` when macOS refused to show some of the contents, for example another app's data without
        /// Full Disk Access. ``bytes`` then counts only what Havus could read, so it may be too low, or zero.
        public let isComplete: Bool
    }

    private static let keys: Set<URLResourceKey> = [
        .isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
    ]

    /// Bytes actually allocated on disk for `url`, recursively for folders and packages.
    ///
    /// Symbolic links are never followed. Unreadable items count as zero; ``measure(_:)`` also says whether there
    /// were any. Blocking; checks for cancellation.
    public static func allocatedSize(of url: URL) -> Int64 {
        measure(url).bytes
    }

    /// Like ``allocatedSize(of:)``, and also tells whether macOS let Havus read everything, so an unreadable folder
    /// doesn't look like an empty one. Blocking; checks for cancellation.
    public static func measure(_ url: URL) -> Measurement {
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: keys.union([.isDirectoryKey]))
        } catch {
            return Measurement(bytes: 0, isComplete: !isPermissionDenied(error))
        }
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            return Measurement(bytes: size(of: values), isComplete: true)
        }

        let wasDenied = OSAllocatedUnfairLock(initialState: false)
        guard
            let enumerator = FileManager.default.enumerator(
                at: url, includingPropertiesForKeys: Array(keys), options: [],
                errorHandler: { _, error in
                    if Self.isPermissionDenied(error) { wasDenied.withLock { $0 = true } }
                    return true
                })
        else { return Measurement(bytes: 0, isComplete: false) }

        var total: Int64 = 0
        var visited = 0
        for case let item as URL in enumerator {
            visited += 1
            if visited.isMultiple(of: 512), Task.isCancelled { break }
            do {
                let values = try item.resourceValues(forKeys: keys)
                guard values.isRegularFile == true || values.isSymbolicLink == true else { continue }
                total += size(of: values)
            } catch {
                if isPermissionDenied(error) { wasDenied.withLock { $0 = true } }
            }
        }
        return Measurement(bytes: total, isComplete: !wasDenied.withLock { $0 })
    }

    private static func size(of values: URLResourceValues) -> Int64 {
        Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }

    /// macOS refused access. An item that disappeared while Havus was looking doesn't count.
    private static func isPermissionDenied(_ error: any Error) -> Bool {
        FileRemover.reason(for: error) == .permissionDenied
    }
}
