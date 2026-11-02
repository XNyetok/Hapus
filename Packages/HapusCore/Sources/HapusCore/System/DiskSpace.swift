import Foundation

public struct DiskSpace: Sendable, Hashable {
    public let volumeName: String
    public let totalBytes: Int64
    /// Free space as Finder reports it, including purgeable space macOS reclaims on demand.
    public let availableBytes: Int64

    public var usedBytes: Int64 { max(0, totalBytes - availableBytes) }
    public var usedFraction: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0 }

    public init(volumeName: String, totalBytes: Int64, availableBytes: Int64) {
        self.volumeName = volumeName
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
    }

    /// The startup disk. Blocking, but fast.
    public static func startupDisk() throws -> DiskSpace {
        let values = try URL(filePath: "/").resourceValues(forKeys: [
            .volumeLocalizedNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ])
        return DiskSpace(
            volumeName: values.volumeLocalizedName ?? "Macintosh HD",
            totalBytes: Int64(values.volumeTotalCapacity ?? 0),
            availableBytes: values.volumeAvailableCapacityForImportantUsage
                ?? Int64(values.volumeAvailableCapacity ?? 0)
        )
    }
}
