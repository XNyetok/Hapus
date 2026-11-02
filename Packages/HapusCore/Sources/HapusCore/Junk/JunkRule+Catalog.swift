extension JunkRule {
    /// Built-in rules.
    ///
    /// Every entry must point at data its owner can regenerate (caches, logs, build products).
    /// Never documents, databases, or user settings. Adding a rule? See CONTRIBUTING.md.
    public static let catalog: [JunkRule] = system + developer

    static let system: [JunkRule] = [
        JunkRule(
            id: .userCaches, group: .system, relativePath: "Library/Caches",
            strategy: .eachChild, safety: .safe,
            // Sync and download state that is expensive or risky to rebuild.
            excludedNames: [
                "CloudKit", "com.apple.bird", "com.apple.nsurlsessiond", "com.apple.akd",
                "com.apple.containermanagerd", "com.apple.HomeKit", "com.apple.homed", "FamilyCircle",
            ]),
        JunkRule(
            id: .userLogs, group: .system, relativePath: "Library/Logs",
            strategy: .eachChild, safety: .safe),
        JunkRule(
            id: .mailDownloads, group: .system,
            relativePath: "Library/Containers/com.apple.mail/Data/Library/Mail Downloads",
            strategy: .wholeContents, safety: .safe, needsFullDiskAccess: true),
        JunkRule(
            id: .iPhoneSoftwareUpdates, group: .system, relativePath: "Library/iTunes/iPhone Software Updates",
            strategy: .wholeContents, safety: .safe),
        JunkRule(
            id: .iPadSoftwareUpdates, group: .system, relativePath: "Library/iTunes/iPad Software Updates",
            strategy: .wholeContents, safety: .safe),
        JunkRule(
            id: .trash, group: .system, relativePath: ".Trash",
            strategy: .wholeContents, safety: .review, removal: .deletePermanently, needsFullDiskAccess: true),
    ]

    static let developer: [JunkRule] = [
        JunkRule(
            id: .xcodeDerivedData, group: .developer, relativePath: "Library/Developer/Xcode/DerivedData",
            strategy: .eachChild, safety: .safe),
        JunkRule(
            id: .xcodeArchives, group: .developer, relativePath: "Library/Developer/Xcode/Archives",
            strategy: .eachChild, safety: .review),
        JunkRule(
            id: .xcodeDeviceSupport, group: .developer, relativePath: "Library/Developer/Xcode/iOS DeviceSupport",
            strategy: .eachChild, safety: .review),
        JunkRule(
            id: .xcodePreviews, group: .developer, relativePath: "Library/Developer/Xcode/UserData/Previews",
            strategy: .wholeContents, safety: .safe),
        JunkRule(
            id: .simulatorCaches, group: .developer, relativePath: "Library/Developer/CoreSimulator/Caches",
            strategy: .wholeContents, safety: .safe),
        JunkRule(
            id: .homebrewCache, group: .developer, relativePath: "Library/Caches/Homebrew",
            strategy: .wholeContents, safety: .safe),
        JunkRule(
            id: .npmCache, group: .developer, relativePath: ".npm/_cacache",
            strategy: .wholeContents, safety: .safe),
        JunkRule(
            id: .yarnCache, group: .developer, relativePath: "Library/Caches/Yarn",
            strategy: .wholeContents, safety: .safe),
        JunkRule(
            id: .pnpmCache, group: .developer, relativePath: "Library/Caches/pnpm",
            strategy: .wholeContents, safety: .safe),
        JunkRule(
            id: .cocoaPodsCache, group: .developer, relativePath: "Library/Caches/CocoaPods",
            strategy: .wholeContents, safety: .safe),
        JunkRule(
            id: .swiftPMCache, group: .developer, relativePath: "Library/Caches/org.swift.swiftpm",
            strategy: .wholeContents, safety: .safe),
        JunkRule(
            id: .pipCache, group: .developer, relativePath: "Library/Caches/pip",
            strategy: .wholeContents, safety: .safe),
        JunkRule(
            id: .goBuildCache, group: .developer, relativePath: "Library/Caches/go-build",
            strategy: .wholeContents, safety: .safe),
        JunkRule(
            id: .gradleCache, group: .developer, relativePath: ".gradle/caches",
            strategy: .wholeContents, safety: .safe),
        JunkRule(
            id: .bunCache, group: .developer, relativePath: ".bun/install/cache",
            strategy: .wholeContents, safety: .safe),
        JunkRule(
            id: .cargoRegistryCache, group: .developer, relativePath: ".cargo/registry/cache",
            strategy: .wholeContents, safety: .safe),
    ]
}
