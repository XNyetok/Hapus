import Foundation
import Testing

@testable import HapusCore

struct JunkScannerTests {
    private func rule(_ id: JunkRule.ID) throws -> JunkRule {
        try #require(JunkRule.catalog.first { $0.id == id })
    }

    @Test func listsEachChildSortedBySize() throws {
        let home = try TemporaryHome()
        try home.makeFile("Library/Caches/com.example.small/blob", bytes: 10_000)
        try home.makeFile("Library/Caches/com.example.big/blob", bytes: 200_000)
        try home.makeFile("Library/Caches/.DS_Store", bytes: 10)

        let result = JunkScanner(home: home.url).scan(try rule(.userCaches))

        #expect(result.status == .ok)
        #expect(result.items.map(\.name) == ["com.example.big", "com.example.small"])
        #expect(result.items[0].size >= 200_000)
        #expect(result.items[0].removalTargets == [result.items[0].url])
    }

    @Test func leavesFoldersClaimedByAnotherRuleToThatRule() throws {
        let home = try TemporaryHome()
        try home.makeFile("Library/Caches/Homebrew/downloads/package.tar.gz", bytes: 50_000)
        try home.makeFile("Library/Caches/com.example.app/cache.db", bytes: 50_000)
        let scanner = JunkScanner(home: home.url)

        let caches = scanner.scan(try rule(.userCaches))
        let homebrew = scanner.scan(try rule(.homebrewCache))

        #expect(caches.items.map(\.name) == ["com.example.app"])
        #expect(homebrew.items.count == 1)
        #expect(homebrew.items[0].removalTargets.map(\.lastPathComponent) == ["downloads"])
    }

    @Test func skipsExcludedNames() throws {
        let home = try TemporaryHome()
        try home.makeFile("Library/Caches/CloudKit/state.db", bytes: 50_000)

        #expect(JunkScanner(home: home.url).scan(try rule(.userCaches)).items.isEmpty)
    }

    @Test func flagsItemsOfRunningApps() throws {
        let home = try TemporaryHome()
        try home.makeFile("Library/Caches/com.example.running/cache.db")
        try home.makeFile("Library/Caches/com.example.idle/cache.db")

        let result = JunkScanner(home: home.url).scan(try rule(.userCaches), inUseNames: ["com.example.running"])
        let inUse = Dictionary(uniqueKeysWithValues: result.items.map { ($0.name, $0.isInUse) })

        #expect(inUse == ["com.example.running": true, "com.example.idle": false])
    }

    @Test func reportsMissingLocations() throws {
        let home = try TemporaryHome()

        let result = JunkScanner(home: home.url).scan(try rule(.xcodeDerivedData))

        #expect(result.status == .notFound)
        #expect(result.items.isEmpty)
    }

    @Test func catalogIsCompleteAndConservative() {
        let ids = JunkRule.catalog.map(\.id)
        #expect(Set(ids).count == ids.count, "Rule IDs must be unique")
        #expect(Set(ids) == Set(JunkRule.ID.allCases), "Every rule ID needs exactly one rule")

        for rule in JunkRule.catalog {
            #expect(!rule.relativePath.hasPrefix("/"), "\(rule.id) must stay inside the home folder")
            #expect(!rule.relativePath.contains(".."), "\(rule.id) must not climb out of the home folder")
        }
        // Only the Trash itself is ever deleted permanently.
        #expect(JunkRule.catalog.filter { $0.removal == .deletePermanently }.map(\.id) == [.trash])
    }
}
