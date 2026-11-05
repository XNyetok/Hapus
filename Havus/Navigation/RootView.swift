import AppKit
import SwiftUI

struct RootView: View {
    @Environment(PermissionCenter.self) private var permissions
    @Environment(UpdateCenter.self) private var updates
    @Environment(ExclusionStore.self) private var exclusions
    @State private var selection: SidebarItem = .overview
    @State private var systemJunk = JunkCleanerModel(group: .system)
    @State private var developerJunk = JunkCleanerModel(group: .developer)
    @State private var uninstaller = UninstallerModel()
    @State private var largeFiles = LargeFilesModel()

    var body: some View {
        NavigationSplitView {
            List(selection: sidebarSelection) {
                row(.overview)
                Section("Bersihin") {
                    row(.systemJunk, badge: systemJunk.badge)
                    row(.developerJunk, badge: developerJunk.badge)
                }
                Section("Kelola") {
                    row(.uninstaller)
                    row(.largeFiles)
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .hidingToolbarTitle()
        .updateCheckAlert(updates)
        // Every page scans and removes with the latest list, and drops results the user just excluded.
        .onChange(of: exclusions.list, initial: true) { _, list in
            systemJunk.setExclusions(list)
            developerJunk.setExclusions(list)
            uninstaller.setExclusions(list)
            largeFiles.setExclusions(list)
        }
        .task { updates.checkIfDue() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.refresh()
            updates.checkIfDue()
        }
    }

    /// The sidebar never ends up with nothing selected.
    private var sidebarSelection: Binding<SidebarItem?> {
        Binding(get: { selection }, set: { if let item = $0 { selection = item } })
    }

    private func row(_ item: SidebarItem, badge: String? = nil) -> some View {
        Label(item.title, systemImage: item.symbol)
            .badge(badge.map { Text($0) })
            .tag(item)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .overview:
            OverviewView { selection = $0 }
        case .systemJunk:
            JunkCleanerView(model: systemJunk, page: .systemJunk)
        case .developerJunk:
            JunkCleanerView(model: developerJunk, page: .developerJunk)
        case .uninstaller:
            UninstallerView(model: uninstaller)
        case .largeFiles:
            LargeFilesView(model: largeFiles)
        }
    }
}

extension View {
    /// Every page has its own large title, so the toolbar doesn't need one (macOS 15+).
    @ViewBuilder
    fileprivate func hidingToolbarTitle() -> some View {
        if #available(macOS 15.0, *) {
            toolbar(removing: .title)
        } else {
            self
        }
    }
}
