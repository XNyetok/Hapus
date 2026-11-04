/// A Havus version number such as `0.2.0`, as the app's `CFBundleShortVersionString` and the release tags
/// (`v0.2.0`) carry it.
public struct AppVersion: Sendable, Hashable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Reads `X.Y.Z`, optionally with a leading `v`. Anything else, such as `1.2` or `1.2.3-beta`, is rejected:
    /// Havus releases are always tagged `vX.Y.Z` (see scripts/build-release.sh).
    public init?(_ text: String) {
        let digits = text.hasPrefix("v") ? text.dropFirst() : Substring(text)
        let parts = digits.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }

        var numbers: [Int] = []
        for part in parts {
            // ASCII digits only, short enough to never overflow an Int.
            guard (1...9).contains(part.count), part.allSatisfy({ ("0"..."9").contains($0) }),
                let number = Int(part)
            else { return nil }
            numbers.append(number)
        }
        self.init(major: numbers[0], minor: numbers[1], patch: numbers[2])
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
