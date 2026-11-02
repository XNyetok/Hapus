import Foundation
import Testing

@testable import HapusCore

struct FileRemoverTests {
    @Test func blockedURLsNeverReachTheFileSystem() throws {
        let home = try TemporaryHome()
        let caches = try home.makeFolder("Library/Caches")
        let inside = try home.makeFile("Library/Caches/com.example.app/cache.db")
        let outside = try home.makeFile("Documents/important.txt")
        let recorder = OperationRecorder()
        let remover = FileRemover(pathGuard: PathGuard(home: home.url)) { url, _ in recorder.record(url) }

        let report = remover.remove([inside, outside], method: .moveToTrash, allowedRoots: [caches])

        #expect(recorder.urls == [inside])
        #expect(report.removed == [inside])
        #expect(report.failures.map(\.reason) == [.blocked(.outsideAllowedRoots)])
    }

    @Test func passesTheRequestedMethodThrough() throws {
        let home = try TemporaryHome()
        let trash = try home.makeFolder(".Trash")
        let file = try home.makeFile(".Trash/old.zip")
        let methods = MethodRecorder()
        let remover = FileRemover(pathGuard: PathGuard(home: home.url)) { _, method in methods.record(method) }

        _ = remover.remove([file], method: .deletePermanently, allowedRoots: [trash])

        #expect(methods.values == [.deletePermanently])
    }

    @Test func deletesPermanentlyWithTheDefaultOperation() throws {
        let home = try TemporaryHome()
        let trash = try home.makeFolder(".Trash")
        let file = try home.makeFile(".Trash/old.zip")

        let report = FileRemover(pathGuard: PathGuard(home: home.url))
            .remove([file], method: .deletePermanently, allowedRoots: [trash])

        #expect(report.failures.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
    }

    @Test func reportsMissingFiles() throws {
        let home = try TemporaryHome()
        let trash = try home.makeFolder(".Trash")

        let report = FileRemover(pathGuard: PathGuard(home: home.url))
            .remove([trash.appending(path: "gone.txt")], method: .deletePermanently, allowedRoots: [trash])

        #expect(report.removed.isEmpty)
        #expect(report.failures.map(\.reason) == [.notFound])
    }
}

private final class MethodRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [FileRemover.Method] = []

    var values: [FileRemover.Method] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func record(_ method: FileRemover.Method) {
        lock.lock()
        storage.append(method)
        lock.unlock()
    }
}
