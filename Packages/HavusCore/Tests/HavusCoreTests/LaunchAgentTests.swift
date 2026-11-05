import Foundation
import Testing

@testable import HavusCore

struct LaunchAgentCatalogTests {
    private let agents = "Library/LaunchAgents"

    @Test func readsTheJobAndWhenItRuns() throws {
        let home = try TemporaryHome()
        let program = try home.makeFile("bin/agent")
        let path = program.path(percentEncoded: false)
        try home.makePlist(
            "\(agents)/com.example.login.plist",
            ["Label": "com.example.login", "ProgramArguments": [path, "--quiet"], "RunAtLoad": true])
        try home.makePlist(
            "\(agents)/com.example.hourly.plist",
            ["Label": "com.example.hourly", "Program": path, "StartInterval": 3600, "RunAtLoad": false])
        try home.makePlist(
            "\(agents)/com.example.always.plist",
            ["Label": "com.example.always", "Program": path, "KeepAlive": true, "RunAtLoad": true])
        try home.makePlist(
            "\(agents)/com.example.restart.plist",
            ["Label": "com.example.restart", "Program": path, "KeepAlive": ["SuccessfulExit": false]])
        try home.makePlist(
            "\(agents)/com.example.daily.plist",
            ["Label": "com.example.daily", "Program": path, "StartCalendarInterval": ["Hour": 9]])
        try home.makePlist(
            "\(agents)/com.example.service.plist",
            [
                "Label": "com.example.service", "Program": path, "MachServices": ["com.example.service": true],
                "Disabled": true,
            ])

        let found = LaunchAgentCatalog(home: home.url).agents()
        let schedules = Dictionary(uniqueKeysWithValues: found.compactMap(\.job).map { ($0.label, $0.schedule) })

        #expect(
            schedules == [
                "com.example.always": .alwaysRunning, "com.example.daily": .calendar,
                "com.example.hourly": .interval(seconds: 3600), "com.example.login": .atLogin,
                "com.example.restart": .atLogin, "com.example.service": .onDemand,
            ])
        let login = try #require(found.first { $0.job?.label == "com.example.login" }?.job)
        #expect(login.program?.path(percentEncoded: false) == path)
        #expect(!login.isProgramMissing)
        #expect(!login.isDisabledInFile)
        #expect(found.first { $0.job?.label == "com.example.service" }?.job?.isDisabledInFile == true)
    }

    @Test func marksFilesLaunchdCantLoad() throws {
        let home = try TemporaryHome()
        // Google Software Update leaves its old agents behind like this: an empty dictionary.
        try home.makePlist("\(agents)/com.example.empty.plist", [:])
        try home.makeFile("\(agents)/com.example.broken.plist", bytes: 64)
        try home.makePlist("\(agents)/com.example.nothing-to-run.plist", ["Label": "com.example.nothing-to-run"])
        try home.makePlist(
            "\(agents)/com.example.bundle.plist",
            ["Label": "com.example.bundle", "BundleProgram": "Contents/MacOS/Helper"])

        let found = LaunchAgentCatalog(home: home.url).agents()

        #expect(
            found.filter { $0.job == nil }.map(\.name) == [
                "com.example.broken", "com.example.empty", "com.example.nothing-to-run",
            ])
        let bundle = try #require(found.first { $0.job?.label == "com.example.bundle" }?.job)
        #expect(bundle.program == nil)
        #expect(!bundle.isProgramMissing)
    }

    @Test func readsOnlyPropertyListsDirectlyInTheFolder() throws {
        let home = try TemporaryHome()
        let job: [String: Any] = ["Label": "com.example.agent", "Program": "/usr/bin/true"]
        try home.makePlist("\(agents)/com.example.agent.plist", job)
        try home.makePlist("\(agents)/disabled/com.example.old.plist", job)
        try home.makePlist("\(agents)/.com.example.hidden.plist", job)
        try home.makeFolder("\(agents)/folder.plist")
        try home.makeFile("\(agents)/notes.txt")

        let found = LaunchAgentCatalog(home: home.url).agents()

        #expect(found.map(\.url.lastPathComponent) == ["com.example.agent.plist"])
    }

    @Test func flagsAMissingProgramOnlyWhenSure() throws {
        let home = try TemporaryHome()
        let locked = try home.makeFolder("Locked")
        let gone = home.url.appending(path: "Applications/Gone.app/Contents/MacOS/Gone").path(percentEncoded: false)
        try home.makePlist("\(agents)/com.example.gone.plist", ["Label": "com.example.gone", "Program": gone])
        try home.makePlist(
            "\(agents)/com.example.command.plist",
            ["Label": "com.example.command", "ProgramArguments": ["sh", "-c", "true"]])
        try home.makePlist(
            "\(agents)/com.example.unplugged.plist",
            ["Label": "com.example.unplugged", "Program": "/Volumes/Unplugged Disk/agent"])
        try home.makePlist(
            "\(agents)/com.example.hidden.plist",
            ["Label": "com.example.hidden", "Program": locked.appending(path: "agent").path(percentEncoded: false)])
        try home.lock(locked)

        let found = LaunchAgentCatalog(home: home.url).agents()

        #expect(found.filter { $0.job?.isProgramMissing == true }.map(\.name) == ["com.example.gone"])
        // The app is gone too, so nothing belongs to it.
        #expect(found.first { $0.job?.label == "com.example.gone" }?.owner == nil)
    }

    @Test func findsTheAppEachAgentBelongsTo() throws {
        let home = try TemporaryHome()
        let applications = try home.makeFolder("Applications")
        try home.makeApp("Applications", name: "Example", bundleID: "com.example.Example")
        try home.makeApp("Applications", name: "Other", bundleID: "com.other.Other")
        try home.makeApp("Library/Application Support/Vendor", name: "Updater", bundleID: "com.vendor.Updater")
        let example = try home.makeFile("Applications/Example.app/Contents/MacOS/Example")
        let updater = try home.makeFile("Library/Application Support/Vendor/Updater.app/Contents/MacOS/Updater")
        let apps = AppCatalog(searchRoots: [applications]).installedApps()
        func job(_ label: String, _ program: URL, _ extra: [String: Any] = [:]) throws {
            try home.makePlist(
                "\(agents)/\(label).plist",
                extra.merging(["Label": label, "Program": program.path(percentEncoded: false)]) { _, new in new })
        }
        let elsewhere = URL(filePath: "/usr/bin/true")

        // What Login Items uses to show an agent under its app.
        try job("com.someone.agent", elsewhere, ["AssociatedBundleIdentifiers": ["com.other.Other"]])
        try job("com.someone.single", elsewhere, ["AssociatedBundleIdentifiers": "com.other.Other"])
        // The app that holds the program, whether or not Hapus Aplikasi lists it.
        try job("com.example.helper", example)
        try job("com.vendor.wake", updater)
        // A label that starts with an app's bundle ID.
        try job("com.example.Example.startup", elsewhere)
        try job("org.unknown.agent", elsewhere)

        let found = LaunchAgentCatalog(home: home.url).agents(installedApps: apps)
        let owners = Dictionary(
            uniqueKeysWithValues: found.compactMap { agent in agent.job.map { ($0.label, agent.owner) } })

        #expect(owners["com.someone.agent"]??.name == "Other")
        #expect(owners["com.someone.single"]??.name == "Other")
        #expect(owners["com.example.helper"]??.installedApp?.bundleIdentifier == "com.example.Example")
        #expect(owners["com.example.Example.startup"]??.name == "Example")
        let vendor = try #require(owners["com.vendor.wake"] ?? nil)
        #expect(vendor.name == "Updater")
        #expect(vendor.installedApp == nil)
        #expect(owners["org.unknown.agent"] == .some(nil))
    }

    @Test func leavesOutExcludedAgents() throws {
        let home = try TemporaryHome()
        let job: [String: Any] = ["Label": "com.example.agent", "Program": "/usr/bin/true"]
        try home.makePlist("\(agents)/com.example.kept.plist", job)
        let excluded = try home.makePlist("\(agents)/com.example.excluded.plist", job)

        let found = LaunchAgentCatalog(home: home.url).agents(excluding: ExclusionList([excluded]))

        #expect(found.map(\.url.lastPathComponent) == ["com.example.kept.plist"])
    }

    @Test func outermostAppHoldsTheProgram() {
        let program = URL(filePath: "/Applications/Example.app/Contents/Library/Helper.app/Contents/MacOS/Helper")

        #expect(
            LaunchAgentCatalog.outermostApp(containing: program)?.path(percentEncoded: false).hasSuffix("Example.app/")
                == true)
        #expect(LaunchAgentCatalog.outermostApp(containing: URL(filePath: "/usr/local/bin/agent")) == nil)
    }
}

struct LaunchdTests {
    private let agent = LaunchAgent(
        url: URL(filePath: "/Users/someone/Library/LaunchAgents/com.example.agent.plist"),
        job: .init(
            label: "com.example.agent", program: URL(filePath: "/usr/bin/true"), isProgramMissing: false,
            schedule: .atLogin, isDisabledInFile: false),
        owner: nil)
    private let disabledInFile = LaunchAgent(
        url: URL(filePath: "/Users/someone/Library/LaunchAgents/com.example.disabled.plist"),
        job: .init(
            label: "com.example.disabled", program: nil, isProgramMissing: false, schedule: .onDemand,
            isDisabledInFile: true),
        owner: nil)
    private let invalid = LaunchAgent(
        url: URL(filePath: "/Users/someone/Library/LaunchAgents/com.example.empty.plist"), job: nil, owner: nil)

    @Test func readsLoadedAndRunningJobs() {
        let output =
            "PID\tStatus\tLabel\n-\t0\tcom.example.idle\n4242\t0\tcom.example.busy\n-\t-9\tcom.example.crashed\nnoise\n"

        let jobs = Launchd.jobs(fromList: output)

        #expect(jobs.loaded == ["com.example.idle", "com.example.busy", "com.example.crashed"])
        #expect(jobs.running == ["com.example.busy"])
    }

    @Test func readsOverridesFromPrintDisabled() {
        // As macOS 27 prints it, plus a line in the older true/false form and a block that isn't about overrides.
        let output = """

            \tdisabled services = {
            \t\t"com.example.off" => disabled
            \t\t"com.example.on" => enabled
            \t\t"com.example.legacy" => true
            \t}

            \tlogin item associations = {
            \t\t"com.example.helper" => "com.example.app"
            \t}

            """

        #expect(
            Launchd.overrides(fromPrintDisabled: output) == [
                "com.example.off": true, "com.example.on": false, "com.example.legacy": true,
            ])
    }

    @Test func statusFollowsLoginItemsThenOverridesThenTheFile() {
        var snapshot = LaunchdSnapshot()
        #expect(agent.status(in: snapshot) == .on)
        #expect(disabledInFile.status(in: snapshot) == .off)
        #expect(invalid.status(in: snapshot) == .invalid)

        snapshot.overrides = ["com.example.agent": true, "com.example.disabled": false]
        #expect(agent.status(in: snapshot) == .off)
        #expect(disabledInFile.status(in: snapshot) == .on)

        snapshot.offInSystemSettings = [agent.url]
        #expect(agent.status(in: snapshot) == .offInSystemSettings)

        snapshot.running = ["com.example.agent"]
        #expect(agent.isRunning(in: snapshot))
        #expect(!disabledInFile.isRunning(in: snapshot))
    }

    @Test func snapshotAsksLoginItemsOnlyAboutAgentsLaunchdCanLoad() {
        let commands = CommandRecorder([
            "list": .init(status: 0, output: "PID\tStatus\tLabel\n12\t0\tcom.example.agent\n"),
            "print-disabled": .init(
                status: 0, output: "disabled services = {\n\t\"com.example.disabled\" => enabled\n}\n"),
        ])
        let asked = OperationRecorder()
        let launchd = Launchd(uid: 501, run: commands.run) { file in
            asked.record(file)
            return true
        }

        let snapshot = launchd.snapshot(of: [agent, invalid])

        #expect(commands.arguments == [["list"], ["print-disabled", "gui/501"]])
        #expect(asked.urls == [agent.url])
        #expect(snapshot.running == ["com.example.agent"])
        #expect(snapshot.overrides == ["com.example.disabled": false])
        #expect(snapshot.offInSystemSettings == [agent.url])
    }

    @Test func turningOffDisablesTheJobThenStopsIt() throws {
        // bootout fails when the job isn't loaded, which isn't a problem.
        let commands = CommandRecorder(["bootout": .init(status: 3, error: "Boot-out failed: 3: No such process")])

        try launchd(commands).turnOff(agent)

        #expect(
            commands.arguments == [
                ["disable", "gui/501/com.example.agent"], ["bootout", "gui/501/com.example.agent"],
            ])
    }

    @Test func aFailedTurnOffStopsNothing() {
        let commands = CommandRecorder(["disable": .init(status: 1, error: "Operation not permitted\n")])

        #expect(throws: Launchd.Failure(message: "Operation not permitted")) {
            try launchd(commands).turnOff(agent)
        }
        #expect(commands.arguments == [["disable", "gui/501/com.example.agent"]])
    }

    @Test func turningOnEnablesTheJobThenLoadsIt() throws {
        // bootstrap fails when the job is loaded already; it's still on.
        let commands = CommandRecorder(["bootstrap": .init(status: 5, error: "Bootstrap failed: 5: Input/output error")]
        )

        try launchd(commands).turnOn(agent)

        #expect(
            commands.arguments == [
                ["enable", "gui/501/com.example.agent"],
                ["bootstrap", "gui/501", "/Users/someone/Library/LaunchAgents/com.example.agent.plist"],
            ])
    }

    @Test func leavesInvalidAgentsAlone() throws {
        let commands = CommandRecorder()

        try launchd(commands).turnOff(invalid)
        try launchd(commands).turnOn(invalid)

        #expect(commands.arguments.isEmpty)
    }

    @Test func removingStopsTheJobOnlyOnceItsFileIsInTheTrash() throws {
        let home = try TemporaryHome()
        let folder = try home.makeFolder("Library/LaunchAgents")
        let job: [String: Any] = ["Label": "com.example.agent", "Program": "/usr/bin/true"]
        try home.makePlist("Library/LaunchAgents/com.example.agent.plist", job)
        let excludedFile = try home.makePlist("Library/LaunchAgents/com.example.excluded.plist", job)
        let found = LaunchAgentCatalog(home: home.url).agents()
        let removable = try #require(found.first { $0.url.lastPathComponent == "com.example.agent.plist" })
        let excluded = try #require(found.first { $0.url.lastPathComponent == "com.example.excluded.plist" })
        let trashed = OperationRecorder()
        let remover = FileRemover(pathGuard: PathGuard(home: home.url, exclusions: ExclusionList([excludedFile]))) {
            url, _ in trashed.record(url)
        }
        let commands = CommandRecorder()

        let report = launchd(commands).remove(removable, with: remover, allowedRoot: folder)
        let refused = launchd(commands).remove(excluded, with: remover, allowedRoot: folder)

        #expect(report.removed == [removable.url])
        #expect(refused.failures.map(\.reason) == [.blocked(.excluded)])
        #expect(trashed.urls == [removable.url])
        #expect(commands.arguments == [["bootout", "gui/501/com.example.agent"]])
    }

    @Test func runsACommandAndCollectsWhatItSays() {
        let result = Launchd.execute(URL(filePath: "/bin/sh"), ["-c", "echo out; echo err >&2; exit 3"])

        #expect(result == .init(status: 3, output: "out\n", error: "err\n"))
    }

    @Test func collectsLongOutputOnBothPipesWithoutHanging() {
        // Far more than a pipe holds, written to standard error first.
        let script = "head -c 300000 /dev/zero | tr '\\0' e >&2; head -c 300000 /dev/zero | tr '\\0' o"

        let result = Launchd.execute(URL(filePath: "/bin/sh"), ["-c", script])

        #expect(result.status == 0)
        #expect(result.output.count == 300_000)
        #expect(result.error.count == 300_000)
    }

    @Test func reportsAProgramThatCantStart() {
        let result = Launchd.execute(URL(filePath: "/nonexistent/launchctl"), [])

        #expect(result.status == -1)
        #expect(!result.error.isEmpty)
    }

    private func launchd(_ commands: CommandRecorder) -> Launchd {
        Launchd(uid: 501, run: commands.run) { _ in false }
    }
}

/// Records launchctl commands instead of running them, and answers like launchctl would.
private final class CommandRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [[String]] = []
    /// By subcommand, such as `disable`. Anything else succeeds without output.
    private let answers: [String: Launchd.CommandResult]

    init(_ answers: [String: Launchd.CommandResult] = [:]) {
        self.answers = answers
    }

    var arguments: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var run: Launchd.Command {
        { [self] arguments in
            lock.lock()
            storage.append(arguments)
            lock.unlock()
            return answers[arguments.first ?? ""] ?? .init(status: 0)
        }
    }
}
