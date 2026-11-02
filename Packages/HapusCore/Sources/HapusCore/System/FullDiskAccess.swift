import Darwin
import Foundation

/// Detects whether the user granted Hapus Full Disk Access.
public enum FullDiskAccess {
    /// Tries to open files macOS reserves for apps with Full Disk Access. Never shows a permission prompt.
    public static func isGranted(home: URL = .homeDirectory) -> Bool {
        let probes = [
            "/Library/Application Support/com.apple.TCC/TCC.db",
            home.appending(path: "Library/Safari/Bookmarks.plist").path(percentEncoded: false),
            home.appending(path: "Library/Safari/CloudTabs.db").path(percentEncoded: false),
        ]
        for path in probes {
            let descriptor = open(path, O_RDONLY)
            if descriptor >= 0 {
                close(descriptor)
                return true
            }
            if errno == EPERM || errno == EACCES { return false }
            // Probe missing on this Mac: try the next one.
        }
        return false
    }
}
