import AppKit
import HavusCore
import Observation
import ServiceManagement

/// Something that went wrong on Jalan Otomatis, shown in an alert.
enum StartupItemsProblem: Equatable {
    case turnOff(name: String, message: String)
    case turnOn(name: String, message: String)
    case remove(file: String, reason: FileRemover.Reason?)
}

/// State for "Jalan Otomatis": the launch agents in `~/Library/LaunchAgents`.
@MainActor
@Observable
final class StartupItemsModel {
    private(set) var agents: [LaunchAgent] = []
    private(set) var snapshot = LaunchdSnapshot()
    /// `false` until Havus has looked at the folder once.
    private(set) var hasLoaded = false
    /// Agents being turned on (`true`) or off, so their switch shows what the user asked for in the meantime.
    private(set) var pendingChanges: [LaunchAgent.ID: Bool] = [:]
    /// File name of the agent that just went to the Trash.
    private(set) var lastRemoval: String?
    var problem: StartupItemsProblem?

    @ObservationIgnored private let catalog = LaunchAgentCatalog()
    @ObservationIgnored private let appCatalog = AppCatalog()
    @ObservationIgnored private let launchd = Launchd()
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var exclusions = ExclusionList()
    /// Every look at launchd gets the next number. A look that started earlier than the one on screen is dropped, so
    /// a slow refresh that began before a change can't undo it on screen.
    @ObservationIgnored private var looksStarted = 0
    @ObservationIgnored private var lookOnScreen = 0

    func status(of agent: LaunchAgent) -> LaunchAgent.Status {
        agent.status(in: snapshot)
    }

    func isRunning(_ agent: LaunchAgent) -> Bool {
        agent.isRunning(in: snapshot)
    }

    /// What the agent's switch shows: the state the user just asked for, or else whether launchd starts it.
    func isOn(_ agent: LaunchAgent) -> Bool {
        pendingChanges[agent.id] ?? (status(of: agent) == .on)
    }

    // MARK: - Loading

    /// Reads the folder and asks launchd about every agent. It's quick, so it runs whenever the page shows up or
    /// Havus comes to the front, in case something changed in the meantime.
    func refresh() {
        loadTask?.cancel()
        let catalog = self.catalog
        let appCatalog = self.appCatalog
        let launchd = self.launchd
        let exclusions = self.exclusions
        let look = nextLook()

        loadTask = Task {
            let (found, snapshot) = await Background.run {
                let agents = catalog.agents(installedApps: appCatalog.installedApps(), excluding: exclusions)
                return (agents, launchd.snapshot(of: agents))
            }
            guard !Task.isCancelled else { return }
            // The list may have changed while Havus was looking.
            agents = self.exclusions == exclusions ? found : found.filter { !self.exclusions.blocks($0.url) }
            hasLoaded = true
            if !show(snapshot, from: look) {
                // A change finished in the meantime. Look again, so agents that are new in this list are covered too.
                await updateSnapshot()
            }
        }
    }

    func rescan() {
        lastRemoval = nil
        refresh()
    }

    /// Removals use `list` from now on, and agents it blocks go away right away.
    func setExclusions(_ list: ExclusionList) {
        guard list != exclusions else { return }
        exclusions = list
        agents.removeAll { list.blocks($0.url) }
    }

    // MARK: - Changing

    /// Turns the agent off or on with launchctl. Both can be undone, and neither touches the file. An agent the user
    /// switched off in System Settings stays as it is: only they can switch it back on, there.
    func setOn(_ isOn: Bool, for agent: LaunchAgent) {
        let status = status(of: agent)
        guard status == .on || status == .off, pendingChanges[agent.id] == nil, isOn != (status == .on) else { return }
        pendingChanges[agent.id] = isOn
        let launchd = self.launchd

        Task {
            let result = await Background.run {
                Result { () throws(Launchd.Failure) in
                    if isOn {
                        try launchd.turnOn(agent)
                    } else {
                        try launchd.turnOff(agent)
                    }
                }
            }
            await updateSnapshot()
            pendingChanges[agent.id] = nil
            if case .failure(let failure) = result {
                problem =
                    isOn
                    ? .turnOn(name: agent.name, message: failure.message)
                    : .turnOff(name: agent.name, message: failure.message)
            }
        }
    }

    /// Moves the agent's file to the Trash through `FileRemover`, then stops the job if it's running.
    func remove(_ agent: LaunchAgent) {
        let launchd = self.launchd
        let catalog = self.catalog
        let exclusions = self.exclusions
        lastRemoval = nil

        Task {
            let report = await Background.run {
                launchd.remove(
                    agent, with: FileRemover(pathGuard: PathGuard(home: catalog.home, exclusions: exclusions)),
                    allowedRoot: catalog.folder)
            }
            if report.removed.contains(agent.url) {
                agents.removeAll { $0.id == agent.id }
                lastRemoval = agent.url.lastPathComponent
                await updateSnapshot()
            } else {
                problem = .remove(file: agent.url.lastPathComponent, reason: report.failures.first?.reason)
                // The file may be gone already.
                refresh()
            }
        }
    }

    private func updateSnapshot() async {
        let launchd = self.launchd
        let agents = self.agents
        let look = nextLook()
        show(await Background.run { launchd.snapshot(of: agents) }, from: look)
    }

    private func nextLook() -> Int {
        looksStarted += 1
        return looksStarted
    }

    /// `false` when a newer look is on screen already, and `snapshot` was dropped.
    @discardableResult
    private func show(_ snapshot: LaunchdSnapshot, from look: Int) -> Bool {
        guard look > lookOnScreen else { return false }
        lookOnScreen = look
        self.snapshot = snapshot
        return true
    }

    // MARK: - Elsewhere

    func reveal(_ agent: LaunchAgent) {
        NSWorkspace.shared.activateFileViewerSelecting([agent.url])
    }

    /// System Settings → General → Login Items & Extensions, where the user manages everything else that starts by
    /// itself, and the switches only they may flip.
    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
