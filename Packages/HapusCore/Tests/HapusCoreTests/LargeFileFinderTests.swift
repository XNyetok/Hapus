import Foundation
import Testing

@testable import HapusCore

struct LargeFileFinderTests {
    @Test func findsBigFilesButSkipsLibraryHiddenFoldersAndPackages() throws {
        let home = try TemporaryHome()
        try home.makeFile("Downloads/movie.mov", bytes: 3_000_000)
        try home.makeFile("Downloads/small.txt", bytes: 10_000)
        try home.makeFile("Documents/.hidden/backup.bin", bytes: 3_000_000)
        try home.makeFile("Documents/Tool.app/Contents/Resources/payload.bin", bytes: 3_000_000)

        let files = LargeFileFinder(home: home.url, usesSpotlight: false)
            .find(LargeFileFinder.Criteria(minimumSize: 2_000_000))

        #expect(files.map(\.url.lastPathComponent) == ["movie.mov"])
    }

    @Test func filtersOutRecentlyUsedFiles() throws {
        let home = try TemporaryHome()
        let old = try home.makeFile("Movies/old.mov", bytes: 3_000_000)
        try home.makeFile("Movies/new.mov", bytes: 3_000_000)
        let twoYearsAgo = Date(timeIntervalSinceNow: -2 * 365 * 24 * 3600)
        try FileManager.default.setAttributes(
            [.modificationDate: twoYearsAgo], ofItemAtPath: old.path(percentEncoded: false))
        let oneYearAgo = Date(timeIntervalSinceNow: -365 * 24 * 3600)

        let files = LargeFileFinder(home: home.url, usesSpotlight: false)
            .find(LargeFileFinder.Criteria(minimumSize: 1_000_000, notOpenedSince: oneYearAgo))

        #expect(files.map(\.url.lastPathComponent) == ["old.mov"])
    }

    @Test func eligibility() {
        let home = ["/", "Users", "someone"]

        #expect(LargeFileFinder.isEligible(home + ["Downloads", "a.zip"], homeComponents: home))
        #expect(!LargeFileFinder.isEligible(home + ["Library", "a.zip"], homeComponents: home))
        #expect(!LargeFileFinder.isEligible(home + [".cache", "a.zip"], homeComponents: home))
        #expect(!LargeFileFinder.isEligible(["/", "tmp", "a.zip"], homeComponents: home))
    }
}

struct DiskSpaceTests {
    @Test func computesUsage() {
        let disk = DiskSpace(volumeName: "Macintosh HD", totalBytes: 1_000, availableBytes: 250)

        #expect(disk.usedBytes == 750)
        #expect(disk.usedFraction == 0.75)
    }
}
