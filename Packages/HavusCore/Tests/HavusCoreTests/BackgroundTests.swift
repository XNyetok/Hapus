import Foundation
import Testing

@testable import HavusCore

struct BackgroundTests {
    @Test func cancellingTheCallerCancelsTheWork() async {
        let caller = Task {
            await Background.run {
                // Stands in for a HavusCore scan, which checks Task.isCancelled as it goes.
                let deadline = Date.now.addingTimeInterval(5)
                while !Task.isCancelled, Date.now < deadline {
                    usleep(1_000)
                }
                return Task.isCancelled
            }
        }
        caller.cancel()

        let workSawCancellation = await caller.value
        #expect(workSawCancellation)
    }

    @Test @MainActor func runsOffTheMainThread() async {
        let ranOnMainThread = await Background.run { Thread.isMainThread }

        #expect(!ranOnMainThread)
    }
}
