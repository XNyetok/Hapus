import Foundation
import Testing

@testable import HavusCore

struct DirectorySizeTests {
    @Test func measuresFoldersRecursively() throws {
        let home = try TemporaryHome()
        try home.makeFile("Data/a.bin", bytes: 100_000)
        try home.makeFile("Data/nested/b.bin", bytes: 50_000)

        let measurement = DirectorySize.measure(home.url.appending(path: "Data"))

        #expect(measurement.bytes >= 150_000)
        #expect(measurement.isComplete)
    }

    @Test func saysWhenItCouldNotReadEverything() throws {
        let home = try TemporaryHome()
        try home.makeFile("Data/readable.bin", bytes: 100_000)
        let locked = try home.makeFolder("Data/locked")
        try home.makeFile("Data/locked/secret.bin", bytes: 100_000)
        try home.lock(locked)

        let partly = DirectorySize.measure(home.url.appending(path: "Data"))
        let nothing = DirectorySize.measure(locked)

        #expect(!partly.isComplete)
        #expect(partly.bytes >= 100_000 && partly.bytes < 200_000)
        #expect(!nothing.isComplete)
        #expect(nothing.bytes == 0)
    }

    @Test func aMissingItemIsEmptyNotUnreadable() throws {
        let home = try TemporaryHome()

        let measurement = DirectorySize.measure(home.url.appending(path: "gone"))

        #expect(measurement == DirectorySize.Measurement(bytes: 0, isComplete: true))
    }

    @Test func allocatedSizeStillCountsWhatItCanRead() throws {
        let home = try TemporaryHome()
        let file = try home.makeFile("Data/a.bin", bytes: 100_000)

        #expect(DirectorySize.allocatedSize(of: file) == DirectorySize.measure(file).bytes)
        #expect(DirectorySize.allocatedSize(of: file) >= 100_000)
    }
}
