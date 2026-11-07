import Darwin
import Foundation
import Testing
import os

@testable import HavusCore

struct DiskUsageScannerTests {
    /// Small numbers, so a few test files are enough to tell big folders from small ones.
    private let scanner = DiskUsageScanner(detailThreshold: 200_000, maximumListed: 3)

    @Test func addsUpEachFolderAndListsTheBiggestFirst() throws {
        let home = try TemporaryHome()
        try home.makeFile("Movies/film.mov", bytes: 400_000)
        try home.makeFile("Movies/clips/clip.mov", bytes: 100_000)
        try home.makeFile("Documents/notes.txt", bytes: 10_000)
        try home.makeFile(".cache/blob", bytes: 250_000)

        let root = scanner.scan(home.url)

        #expect(root.kind == .folder)
        #expect(root.isComplete)
        #expect(root.children?.map(\.name) == ["Movies", ".cache", "Documents"])
        #expect(root.bytes == root.children?.reduce(0) { $0 + $1.bytes })
        let movies = try #require(root.children?.first)
        #expect(movies.bytes >= 500_000)
        #expect(movies.children?.map(\.name) == ["film.mov", "clips"])
    }

    @Test func smallFoldersKeepNoListUntilScannedOnTheirOwn() throws {
        let home = try TemporaryHome()
        try home.makeFile("Big/a.bin", bytes: 300_000)
        try home.makeFile("Big/Small/b.bin", bytes: 20_000)
        try home.makeFile("Big/Small/c.bin", bytes: 10_000)

        let big = try #require(scanner.scan(home.url).children?.first)
        let small = try #require(big.children?.first { $0.name == "Small" })

        #expect(big.children != nil)
        #expect(small.kind == .folder)
        #expect(small.children == nil)
        #expect(small.bytes >= 30_000)

        let scanned = scanner.scan(small.url)
        #expect(scanned.children?.map(\.name) == ["b.bin", "c.bin"])
        #expect(scanned.bytes == small.bytes)
    }

    @Test func foldsTheRestIntoOtherItems() throws {
        let home = try TemporaryHome()
        for (index, size) in [50_000, 40_000, 30_000, 20_000, 10_000].enumerated() {
            try home.makeFile("Folder/file\(index).bin", bytes: size)
        }

        let folder = scanner.scan(home.url.appending(path: "Folder"))
        let listed = try #require(folder.children)

        #expect(listed.map(\.name) == ["file0.bin", "file1.bin", "file2.bin"])
        #expect(folder.otherItems.count == 2)
        #expect(folder.otherItems.bytes >= 30_000)
        #expect(folder.bytes == listed.reduce(0) { $0 + $1.bytes } + folder.otherItems.bytes)
    }

    @Test func keepsTheBiggestItemsWhateverOrderTheyComeIn() throws {
        let home = try TemporaryHome()
        let sizes = (1...20).map { $0 * 8_192 }
        for (index, size) in sizes.shuffled().enumerated() {
            try home.makeFile("Folder/item\(index).bin", bytes: size)
        }

        let folder = scanner.scan(home.url.appending(path: "Folder"))
        let listed = try #require(folder.children)
        let everything = try FileManager.default.contentsOfDirectory(
            at: home.url.appending(path: "Folder"), includingPropertiesForKeys: nil
        ).map(DirectorySize.allocatedSize(of:)).sorted(by: >)

        #expect(listed.map(\.bytes) == Array(everything.prefix(3)))
        #expect(folder.otherItems.count == 17)
        #expect(folder.otherItems.bytes == everything.dropFirst(3).reduce(0, +))
    }

    @Test func measuresPackagesAsAWhole() throws {
        let home = try TemporaryHome()
        let app = try home.makeApp("Applications", name: "Tool", bundleID: "com.example.tool")
        try home.makeFile("Applications/Tool.app/Contents/MacOS/Tool", bytes: 300_000)

        let applications = scanner.scan(home.url.appending(path: "Applications"))
        let tool = try #require(applications.children?.first)

        #expect(tool.url.lastPathComponent == app.lastPathComponent)
        #expect(tool.kind == .package)
        #expect(tool.children == nil)
        #expect(tool.bytes >= 300_000)
    }

    @Test func neverFollowsSymbolicLinks() throws {
        let home = try TemporaryHome()
        let big = try home.makeFolder("Big")
        try home.makeFile("Big/a.bin", bytes: 400_000)
        try home.makeFolder("Links")
        let link = home.url.appending(path: "Links/big")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: big)

        let links = scanner.scan(home.url.appending(path: "Links"))
        let item = try #require(links.children?.first)

        #expect(item.kind == .file)
        #expect(item.bytes < 400_000)
    }

    @Test func saysWhenItCouldNotReadEverything() throws {
        let home = try TemporaryHome()
        try home.makeFile("Data/readable.bin", bytes: 300_000)
        let locked = try home.makeFolder("Data/Locked")
        try home.makeFile("Data/Locked/secret.bin", bytes: 300_000)
        try home.lock(locked)

        let data = scanner.scan(home.url.appending(path: "Data"))
        let lockedItem = try #require(data.children?.first { $0.name == "Locked" })

        #expect(!data.isComplete)
        #expect(data.bytes >= 300_000 && data.bytes < 600_000)
        #expect(!lockedItem.isComplete)
        #expect(lockedItem.bytes == 0)
        #expect(lockedItem.children?.isEmpty == true)
    }

    @Test func aMissingFolderIsEmptyNotUnreadable() throws {
        let home = try TemporaryHome()

        let gone = scanner.scan(home.url.appending(path: "gone"))

        #expect(gone.bytes == 0)
        #expect(gone.isComplete)
    }

    @Test func reportsProgress() throws {
        let home = try TemporaryHome()
        try home.makeFile("a.bin", bytes: 100_000)
        let reports = OSAllocatedUnfairLock(initialState: [DiskUsageScanner.Progress]())

        let root = scanner.scan(home.url) { progress in reports.withLock { $0.append(progress) } }

        let first = try #require(reports.withLock { $0.first })
        #expect(first.itemCount >= 1)
        #expect(first.bytes <= root.bytes)
    }

    @Test func neverDownloadsCloudOnlyFilesWhileScanning() {
        let type = IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES
        let before = getiopolicy_np(type, IOPOL_SCOPE_THREAD)

        let during = DiskUsageScanner.withoutDownloading { getiopolicy_np(type, IOPOL_SCOPE_THREAD) }

        #expect(during == IOPOL_MATERIALIZE_DATALESS_FILES_OFF)
        #expect(getiopolicy_np(type, IOPOL_SCOPE_THREAD) == before)
    }
}
