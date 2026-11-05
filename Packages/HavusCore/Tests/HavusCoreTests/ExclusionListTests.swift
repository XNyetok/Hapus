import Foundation
import Testing

@testable import HavusCore

struct ExclusionListTests {
    @Test func blocksTheItemEverythingInsideItAndFoldersThatHoldIt() throws {
        let home = try TemporaryHome()
        let models = try home.makeFolder("Library/Caches/com.example.keep/models")
        let list = ExclusionList([models])

        #expect(list.blocks(models))
        #expect(list.blocks(models.appending(path: "model.bin")))
        // Removing either folder would remove the excluded one with it.
        #expect(list.blocks(home.url.appending(path: "Library/Caches/com.example.keep")))
        #expect(list.blocks(home.url.appending(path: "Library/Caches")))
    }

    @Test func leavesSiblingsAloneEvenWithACommonPrefix() throws {
        let home = try TemporaryHome()
        let keep = try home.makeFolder("Library/Caches/com.example.keep")
        let list = ExclusionList([keep])

        #expect(!list.blocks(home.url.appending(path: "Library/Caches/com.example.keeper")))
        #expect(!list.blocks(home.url.appending(path: "Library/Caches/com.example.other/cache.db")))
    }

    @Test func ignoresCaseAndUnicodeNormalization() throws {
        let home = try TemporaryHome()
        let keep = try home.makeFolder("Library/Caches/Caf\u{E9}")

        #expect(ExclusionList([keep]).blocks(home.url.appending(path: "library/caches/CAFE\u{301}/data")))
    }

    @Test func seesThroughSymlinkedParents() throws {
        let home = try TemporaryHome()
        let real = try home.makeFolder("Real/Keep")
        let link = home.url.appending(path: "Link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: home.url.appending(path: "Real"))

        #expect(ExclusionList([link.appending(path: "Keep")]).blocks(real.appending(path: "file")))
        #expect(ExclusionList([real]).blocks(link.appending(path: "Keep/file")))
    }

    @Test func anEmptyListBlocksNothing() {
        let list = ExclusionList()

        #expect(list.isEmpty)
        #expect(!list.blocks(URL(filePath: "/Users/someone/Library/Caches/com.example.app")))
    }
}

/// Every place that offers or removes files respects the list.
struct ExclusionEnforcementTests {
    private func rule(_ id: JunkRule.ID) throws -> JunkRule {
        try #require(JunkRule.catalog.first { $0.id == id })
    }

    @Test func pathGuardDeniesExcludedItemsAndFoldersThatHoldThem() throws {
        let home = try TemporaryHome()
        let caches = try home.makeFolder("Library/Caches")
        let models = try home.makeFolder("Library/Caches/com.example.keep/models")
        let other = try home.makeFolder("Library/Caches/com.example.other")
        let guardian = PathGuard(home: home.url, exclusions: ExclusionList([models]))

        #expect(guardian.check(models, allowedRoots: [caches]) == .denied(.excluded))
        #expect(guardian.check(models.appending(path: "model.bin"), allowedRoots: [caches]) == .denied(.excluded))
        #expect(guardian.check(models.deletingLastPathComponent(), allowedRoots: [caches]) == .denied(.excluded))
        #expect(guardian.check(other, allowedRoots: [caches]) == .allowed)
    }

    @Test func excludedItemsNeverReachTheFileSystem() throws {
        let home = try TemporaryHome()
        let caches = try home.makeFolder("Library/Caches")
        let keep = try home.makeFile("Library/Caches/com.example.keep/cache.db")
        let other = try home.makeFile("Library/Caches/com.example.other/cache.db")
        let recorder = OperationRecorder()
        let guardian = PathGuard(home: home.url, exclusions: ExclusionList([keep]))
        let remover = FileRemover(pathGuard: guardian) { url, _ in recorder.record(url) }

        let report = remover.remove([keep, other], method: .moveToTrash, allowedRoots: [caches])

        #expect(recorder.urls == [other])
        #expect(report.failures.map(\.reason) == [.blocked(.excluded)])
    }

    @Test func junkScanLeavesOutExcludedItemsAndFoldersThatHoldThem() throws {
        let home = try TemporaryHome()
        let keep = try home.makeFolder("Library/Caches/com.example.keep")
        try home.makeFile("Library/Caches/com.example.keep/cache.db")
        let nested = try home.makeFile("Library/Caches/com.example.mixed/keep/state.db")
        try home.makeFile("Library/Caches/com.example.mixed/junk.db")
        try home.makeFile("Library/Caches/com.example.other/cache.db")

        let result = JunkScanner(home: home.url)
            .scan(try rule(.userCaches), excluding: ExclusionList([keep, nested]))

        #expect(result.items.map(\.name) == ["com.example.other"])
    }

    @Test func wholeContentsRulesLeaveOutExcludedChildren() throws {
        let home = try TemporaryHome()
        let keep = try home.makeFile("Library/Caches/Homebrew/downloads/keep.tar.gz", bytes: 500_000)
        try home.makeFile("Library/Caches/Homebrew/api/formula.json", bytes: 10_000)

        let result = JunkScanner(home: home.url).scan(try rule(.homebrewCache), excluding: ExclusionList([keep]))

        #expect(result.items.count == 1)
        #expect(result.items.first?.removalTargets.map(\.lastPathComponent) == ["api"])
        #expect((result.items.first?.size ?? .max) < 500_000)
    }

    @Test func excludingAResultDropsItemsWithBlockedTargets() throws {
        let home = try TemporaryHome()
        let keep = try home.makeFile("Library/Caches/com.example.keep/cache.db")
        try home.makeFile("Library/Caches/com.example.other/cache.db")
        let result = JunkScanner(home: home.url).scan(try rule(.userCaches))

        let filtered = result.excluding(ExclusionList([keep]))

        #expect(result.items.count == 2)
        #expect(filtered.items.map(\.name) == ["com.example.other"])
    }

    @Test func leftoverFinderLeavesOutExcludedData() throws {
        let home = try TemporaryHome()
        let keep = try home.makeFile("Library/Application Support/com.example.Example/data.db")
        try home.makeFile("Library/Caches/com.example.Example/cache")
        let app = InstalledApp(
            url: URL(filePath: "/Applications/Example.app"), name: "Example",
            bundleIdentifier: "com.example.Example", bundleName: "Example", version: "1.0")

        let found = LeftoverFinder(home: home.url).leftovers(for: app, excluding: ExclusionList([keep]))

        #expect(found.map(\.kind) == [.caches])
    }

    @Test func largeFileFinderLeavesOutExcludedFiles() throws {
        let home = try TemporaryHome()
        let disk = try home.makeFile("Documents/VMs/dev.vmdk", bytes: 3_000_000)
        try home.makeFile("Downloads/installer.dmg", bytes: 3_000_000)

        let files = LargeFileFinder(home: home.url, usesSpotlight: false).find(
            LargeFileFinder.Criteria(minimumSize: 2_000_000),
            excluding: ExclusionList([disk.deletingLastPathComponent()]))

        #expect(files.map(\.url.lastPathComponent) == ["installer.dmg"])
    }
}
