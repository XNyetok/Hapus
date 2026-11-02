import AppKit
import HavusCore
import Observation

struct RemovalSummary: Equatable {
    let count: Int
    let bytes: Int64
    let failedCount: Int
}

@MainActor
@Observable
final class LargeFilesModel {
    enum Phase: Equatable {
        case idle, searching, results, removing
    }

    enum MinimumSize: Int64, CaseIterable, Identifiable {
        case mb50 = 50_000_000
        case mb100 = 100_000_000
        case mb500 = 500_000_000
        case gb1 = 1_000_000_000

        var id: Self { self }
        var label: String { Format.bytes(rawValue) }
    }

    enum LastOpened: Int, CaseIterable, Identifiable {
        case any = 0
        case threeMonths = 90
        case sixMonths = 180
        case oneYear = 365

        var id: Self { self }

        var cutoff: Date? {
            self == .any ? nil : Calendar.current.date(byAdding: .day, value: -rawValue, to: .now)
        }
    }

    var minimumSize: MinimumSize = .mb100
    var lastOpened: LastOpened = .any
    private(set) var phase: Phase = .idle
    private(set) var files: [LargeFile] = []
    var selection: Set<LargeFile.ID> = []
    private(set) var lastRemoval: RemovalSummary?

    @ObservationIgnored private let finder = LargeFileFinder()
    @ObservationIgnored private var task: Task<Void, Never>?

    var selectedFiles: [LargeFile] { files.filter { selection.contains($0.id) } }
    var selectedSize: Int64 { selectedFiles.reduce(0) { $0 + $1.size } }
    var totalSize: Int64 { files.reduce(0) { $0 + $1.size } }

    func search() {
        task?.cancel()
        let finder = self.finder
        let criteria = LargeFileFinder.Criteria(minimumSize: minimumSize.rawValue, notOpenedSince: lastOpened.cutoff)
        selection = []
        lastRemoval = nil
        phase = .searching

        task = Task {
            let found = await Background.run { finder.find(criteria) }
            guard !Task.isCancelled else { return }
            files = found
            phase = .results
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = files.isEmpty ? .idle : .results
    }

    func toggle(_ file: LargeFile) {
        if selection.contains(file.id) {
            selection.remove(file.id)
        } else {
            selection.insert(file.id)
        }
    }

    func reveal(_ file: LargeFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    func open(_ file: LargeFile) {
        NSWorkspace.shared.open(file.url)
    }

    func moveSelectionToTrash() {
        let targets = selectedFiles
        guard !targets.isEmpty else { return }
        let home = finder.home
        phase = .removing

        task = Task {
            let report = await Task.detached(priority: .userInitiated) {
                FileRemover(pathGuard: PathGuard(home: home))
                    .remove(targets.map(\.url), method: .moveToTrash, allowedRoots: [home])
            }.value
            let removed = Set(report.removed)
            files.removeAll { removed.contains($0.url) }
            selection.subtract(removed)
            lastRemoval = RemovalSummary(
                count: removed.count,
                bytes: targets.filter { removed.contains($0.url) }.reduce(0) { $0 + $1.size },
                failedCount: report.failures.count
            )
            phase = .results
        }
    }
}
