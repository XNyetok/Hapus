/// Runs blocking HavusCore work, such as a scan, away from the caller's actor.
public enum Background {
    /// Runs `work` in a detached task and returns its result.
    ///
    /// Awaiting a bare `Task.detached` ignores the caller's cancellation, so a scan would keep running after
    /// the user cancels it. Here, cancelling the calling task also cancels the detached one, so the
    /// `Task.isCancelled` checks inside `work` can stop it early.
    public static func run<T: Sendable>(
        priority: TaskPriority = .userInitiated, _ work: @escaping @Sendable () -> T
    ) async -> T {
        let task = Task.detached(priority: priority, operation: work)
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
