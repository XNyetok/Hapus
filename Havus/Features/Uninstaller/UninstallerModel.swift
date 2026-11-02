import AppKit
import HavusCore
import Observation

struct UninstallOutcome: Equatable {
    let appName: String
    let removedApp: Bool
    let removedLeftovers: Int
    let bytes: Int64
    let failedCount: Int
    /// macOS refused to move the app bundle itself.
    let appBlocked: Bool
}

@MainActor
@Observable
final class UninstallerModel {
    private(set) var apps: [InstalledApp] = []
    private(set) var isLoadingApps = false
    private(set) var sizes: [InstalledApp.ID: Int64] = [:]
    var searchText = ""

    private(set) var selectedAppID: InstalledApp.ID?
    private(set) var leftovers: [Leftover] = []
    private(set) var isLoadingLeftovers = false
    var leftoverSelection: Set<Leftover.ID> = []
    var includesApp = true
    private(set) var isSelectedAppRunning = false
    private(set) var isRemoving = false
    private(set) var outcome: UninstallOutcome?

    @ObservationIgnored private let catalog = AppCatalog()
    @ObservationIgnored private let finder = LeftoverFinder()
    @ObservationIgnored private var appsTask: Task<Void, Never>?
    @ObservationIgnored private var leftoverTask: Task<Void, Never>?

    var filteredApps: [InstalledApp] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    var selectedApp: InstalledApp? { apps.first { $0.id == selectedAppID } }

    var selectedLeftovers: [Leftover] { leftovers.filter { leftoverSelection.contains($0.id) } }

    var selectedBytes: Int64 {
        let appBytes = includesApp ? (selectedAppID.flatMap { sizes[$0] } ?? 0) : 0
        return selectedLeftovers.reduce(appBytes) { $0 + $1.size }
    }

    var canRemove: Bool {
        selectedApp != nil && !isSelectedAppRunning && !isRemoving && !isLoadingLeftovers
            && (includesApp || !leftoverSelection.isEmpty)
    }

    // MARK: - Loading

    func loadAppsIfNeeded() {
        guard apps.isEmpty, !isLoadingApps else { return }
        isLoadingApps = true
        let catalog = self.catalog

        appsTask = Task {
            let found = await Task.detached(priority: .userInitiated) { catalog.installedApps() }.value
            apps = found
            isLoadingApps = false
            await measureSizes(of: found)
        }
    }

    /// Measures app sizes a few at a time, so the list fills in progressively.
    private func measureSizes(of apps: [InstalledApp]) async {
        await withTaskGroup(of: (InstalledApp.ID, Int64).self) { group in
            var pending = apps.makeIterator()
            for _ in 0..<3 {
                guard let app = pending.next() else { break }
                group.addTask { (app.id, DirectorySize.allocatedSize(of: app.url)) }
            }
            for await (id, size) in group {
                sizes[id] = size
                if let app = pending.next() {
                    group.addTask { (app.id, DirectorySize.allocatedSize(of: app.url)) }
                }
            }
        }
    }

    func select(_ id: InstalledApp.ID?) {
        leftoverTask?.cancel()
        selectedAppID = id
        leftovers = []
        leftoverSelection = []
        includesApp = true
        outcome = nil
        refreshRunningState()
        guard let app = selectedApp else {
            isLoadingLeftovers = false
            return
        }

        isLoadingLeftovers = true
        let finder = self.finder
        let otherApps = Set(apps.map(\.bundleIdentifier)).subtracting([app.bundleIdentifier])
        leftoverTask = Task {
            let found = await Background.run { finder.leftovers(for: app, otherBundleIdentifiers: otherApps) }
            guard !Task.isCancelled, selectedAppID == app.id else { return }
            leftovers = found
            // Name-based matches need a human look, so they start unselected.
            leftoverSelection = Set(found.filter { $0.match == .bundleIdentifier }.map(\.id))
            isLoadingLeftovers = false
        }
    }

    func toggleLeftover(_ leftover: Leftover) {
        if leftoverSelection.contains(leftover.id) {
            leftoverSelection.remove(leftover.id)
        } else {
            leftoverSelection.insert(leftover.id)
        }
    }

    // MARK: - Running apps

    func refreshRunningState() {
        guard let app = selectedApp else {
            isSelectedAppRunning = false
            return
        }
        isSelectedAppRunning = !NSRunningApplication.runningApplications(
            withBundleIdentifier: app.bundleIdentifier
        ).isEmpty
    }

    func quitSelectedApp() {
        guard let app = selectedApp else { return }
        for running in NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier) {
            running.terminate()
        }
    }

    // MARK: - Removing

    func removeSelection() {
        // The app may have been opened since it was selected.
        refreshRunningState()
        guard canRemove, let app = selectedApp else { return }
        let appTargets = includesApp ? [app.url] : []
        let leftoverTargets = selectedLeftovers
        let appSize = sizes[app.id] ?? 0
        let appRoots = catalog.searchRoots
        let leftoverRoots = finder.searchRoots
        isRemoving = true

        Task {
            let (appReport, leftoverReport) = await Task.detached(priority: .userInitiated) {
                let remover = FileRemover(pathGuard: PathGuard())
                return (
                    remover.remove(appTargets, method: .moveToTrash, allowedRoots: appRoots),
                    remover.remove(leftoverTargets.map(\.url), method: .moveToTrash, allowedRoots: leftoverRoots)
                )
            }.value

            let removedApp = !appReport.removed.isEmpty
            let removedLeftoverURLs = Set(leftoverReport.removed)
            let leftoverBytes = leftoverTargets.filter { removedLeftoverURLs.contains($0.url) }.reduce(0) {
                $0 + $1.size
            }
            if removedApp {
                apps.removeAll { $0.id == app.id }
            }
            selectedAppID = nil
            leftovers = []
            leftoverSelection = []
            isRemoving = false
            outcome = UninstallOutcome(
                appName: app.name,
                removedApp: removedApp,
                removedLeftovers: removedLeftoverURLs.count,
                bytes: (removedApp ? appSize : 0) + leftoverBytes,
                failedCount: appReport.failures.count + leftoverReport.failures.count,
                appBlocked: !appReport.failures.isEmpty
            )
        }
    }
}
