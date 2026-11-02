import Foundation
import Testing

@testable import HapusCore

struct PathGuardTests {
    @Test func allowsItemsStrictlyInsideAnAllowedRoot() throws {
        let home = try TemporaryHome()
        let caches = try home.makeFolder("Library/Caches")
        let item = try home.makeFolder("Library/Caches/com.example.app")

        #expect(PathGuard(home: home.url).check(item, allowedRoots: [caches]) == .allowed)
    }

    @Test func neverAllowsTheRootItself() throws {
        let home = try TemporaryHome()
        let caches = try home.makeFolder("Library/Caches")

        #expect(PathGuard(home: home.url).check(caches, allowedRoots: [caches]) == .denied(.outsideAllowedRoots))
    }

    @Test func rejectsSiblingsThatOnlySharePrefix() throws {
        let home = try TemporaryHome()
        let caches = try home.makeFolder("Library/Caches")
        let sibling = try home.makeFile("Library/Caches2/data.db")

        #expect(PathGuard(home: home.url).check(sibling, allowedRoots: [caches]) == .denied(.outsideAllowedRoots))
    }

    @Test func rejectsDotDotTraversal() throws {
        let home = try TemporaryHome()
        let caches = try home.makeFolder("Library/Caches")
        try home.makeFile("Documents/secret.txt")
        let sneaky = caches.appending(path: "../../Documents/secret.txt")

        #expect(PathGuard(home: home.url).check(sneaky, allowedRoots: [caches]) == .denied(.outsideAllowedRoots))
    }

    @Test func judgesSymlinksAsTheLinkNeverTheDestination() throws {
        let home = try TemporaryHome()
        let caches = try home.makeFolder("Library/Caches")
        let documents = try home.makeFolder("Documents")
        try home.makeFile("Documents/thesis.pages")
        let link = caches.appending(path: "innocent-looking")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: documents)
        let guardian = PathGuard(home: home.url)

        // Reaching through the link escapes the allowed root.
        #expect(
            guardian.check(link.appending(path: "thesis.pages"), allowedRoots: [caches])
                == .denied(.outsideAllowedRoots))
        // Removing the link itself only removes the link.
        #expect(guardian.check(link, allowedRoots: [caches]) == .allowed)
    }

    @Test(arguments: ["Desktop", "Documents", "Downloads", "Library", "Pictures", ".Trash"])
    func protectsStandardFolders(name: String) throws {
        let home = try TemporaryHome()
        let folder = try home.makeFolder(name)

        #expect(PathGuard(home: home.url).check(folder, allowedRoots: [home.url]) == .denied(.protectedLocation))
    }

    @Test func protectsTheHomeFolderItself() throws {
        let home = try TemporaryHome()
        let parent = home.url.deletingLastPathComponent()

        #expect(PathGuard(home: home.url).check(home.url, allowedRoots: [parent]) == .denied(.protectedLocation))
    }

    @Test(arguments: ["Library/Mobile Documents/com~apple~CloudDocs/notes.txt", "Library/CloudStorage/Dropbox/a.pdf"])
    func neverTouchesCloudStorage(relativePath: String) throws {
        let home = try TemporaryHome()
        let file = try home.makeFile(relativePath)

        #expect(PathGuard(home: home.url).check(file, allowedRoots: [home.url]) == .denied(.insideProtectedArea))
    }

    @Test func rejectsSystemLocations() {
        let guardian = PathGuard(home: URL(filePath: "/Users/nobody"))
        let roots = [URL(filePath: "/")]

        #expect(guardian.check(URL(filePath: "/System/Library/CoreServices"), allowedRoots: roots) != .allowed)
        #expect(guardian.check(URL(filePath: "/usr/bin/true"), allowedRoots: roots) != .allowed)
        #expect(guardian.check(URL(filePath: "/Applications"), allowedRoots: roots) == .denied(.protectedLocation))
    }

    @Test func rejectsNonFileURLs() throws {
        let guardian = PathGuard(home: URL(filePath: "/Users/nobody"))
        let url = try #require(URL(string: "https://example.com/file"))

        #expect(guardian.check(url, allowedRoots: [URL(filePath: "/Users/nobody")]) == .denied(.notAFileURL))
    }
}
