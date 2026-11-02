import Foundation

/// A throwaway home folder, deleted when the test ends. Tests never touch the real home folder.
final class TemporaryHome {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appending(path: "HavusTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    @discardableResult
    func makeFile(_ relativePath: String, bytes: Int = 4_096) throws -> URL {
        let file = url.appending(path: relativePath)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0xA5, count: bytes).write(to: file)
        return file
    }

    @discardableResult
    func makeFolder(_ relativePath: String) throws -> URL {
        let folder = url.appending(path: relativePath, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Creates `<name>.app/Contents/Info.plist` inside `folder`.
    @discardableResult
    func makeApp(_ relativeFolder: String, name: String, bundleID: String?, version: String? = nil) throws -> URL {
        let app = try makeFolder("\(relativeFolder)/\(name).app")
        let contents = try makeFolder("\(relativeFolder)/\(name).app/Contents")
        var info: [String: Any] = ["CFBundleName": name]
        info["CFBundleIdentifier"] = bundleID
        info["CFBundleShortVersionString"] = version
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: contents.appending(path: "Info.plist"))
        return app
    }
}

/// Records the URLs passed to an injected file operation.
final class OperationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []

    var urls: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func record(_ url: URL) {
        lock.lock()
        storage.append(url)
        lock.unlock()
    }
}
