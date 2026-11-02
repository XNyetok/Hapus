import HapusCore
import SwiftUI

struct JunkCleanerView: View {
    @Bindable var model: JunkCleanerModel
    let page: SidebarItem
    @State private var isConfirmingClean = false
    @State private var isConfirmingEmptyTrash = false

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(item: page)
                .padding([.horizontal, .top], Design.Spacing.xxl)
                .padding(.bottom, Design.Spacing.l)
            content
        }
        .confirmationDialog(
            Text("Bersihin \(model.selectedItems.count) item?"), isPresented: $isConfirmingClean,
            titleVisibility: .visible
        ) {
            Button("Bersihin \(Format.bytes(model.selectedSize))", role: .destructive) { model.clean() }
            Button("Batal", role: .cancel) {}
        } message: {
            Text(
                model.selectionIncludesPermanentDeletion
                    ? "Isi Tong Sampah yang dipilih bakal dihapus permanen. Sisanya dipindah ke Tong Sampah, jadi masih bisa dibalikin."
                    : "Semuanya dipindah ke Tong Sampah, jadi masih bisa dibalikin kalau kamu berubah pikiran."
            )
        }
        .confirmationDialog("Kosongin Tong Sampah?", isPresented: $isConfirmingEmptyTrash, titleVisibility: .visible) {
            Button("Kosongin", role: .destructive) { model.emptyTrash() }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Semua isi Tong Sampah bakal dihapus permanen dan nggak bisa dibalikin.")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            MessageView(
                symbol: page.symbol,
                title: model.group == .system ? "Siap bersih-bersih?" : "Bersihin sisa ngoding?",
                message: Text(
                    model.group == .system
                        ? "Hapus bakal ngecek cache, log, dan file sisa yang aman dibuang. Kamu tetap bisa milih mana yang mau dihapus."
                        : "Hapus bakal ngecek DerivedData Xcode, cache simulator, sampai cache npm, Homebrew, dan Cargo."
                ),
                actionTitle: "Pindai Sekarang"
            ) { model.scan() }

        case .scanning(let finished, let total):
            VStack(spacing: Design.Spacing.l) {
                ProgressView(value: Double(finished), total: Double(max(total, 1)))
                    .frame(maxWidth: 320)
                Text("Lagi nyari sampah… \(finished) dari \(total) lokasi")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Button("Batal") { model.cancel() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .results where model.visibleResults.isEmpty:
            MessageView(
                symbol: "checkmark.seal",
                title: "Bersih kinclong!",
                message: Text("Nggak ada sampah yang ketemu di sini."),
                actionTitle: "Pindai Lagi"
            ) { model.scan() }

        case .results:
            results

        case .cleaning:
            ProgressView("Lagi dibersihin…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .finished(let summary):
            FinishedView(
                summary: summary,
                onScanAgain: { model.scan() },
                onEmptyTrash: { isConfirmingEmptyTrash = true })
        }
    }

    private var results: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(model.visibleResults) { result in
                        JunkResultRow(result: result, model: model)
                    }
                } header: {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(Format.bytes(model.totalSize)) bisa dibersihin")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Button("Pindai Ulang") { model.scan() }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                    }
                    .padding(.bottom, Design.Spacing.s)
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .contentMargins(.horizontal, Design.Spacing.l, for: .scrollContent)

            ActionBar {
                Text("\(model.selection.count) item dipilih · \(Format.bytes(model.selectedSize))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } trailing: {
                Button("Bersihin") { isConfirmingClean = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.selection.isEmpty)
            }
        }
    }
}

private struct JunkResultRow: View {
    let result: JunkScanResult
    let model: JunkCleanerModel
    @State private var isExpanded = false

    var body: some View {
        if result.status == .noPermission {
            PermissionRow(rule: result.rule)
        } else if result.rule.strategy == .wholeContents, let item = result.items.first {
            header(state: model.selection.contains(item.id) ? .on : .off) { model.toggle(item) }
        } else {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(result.items) { item in
                    JunkItemRow(item: item, isSelected: model.selection.contains(item.id)) { model.toggle(item) }
                }
            } label: {
                header(state: model.selectionState(of: result)) { model.toggleAll(in: result) }
            }
        }
    }

    private func header(state: CheckState, toggle: @escaping () -> Void) -> some View {
        HStack(spacing: Design.Spacing.m) {
            SelectionBox(state: state, action: toggle)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Design.Spacing.s) {
                    Text(result.rule.id.title)
                        .font(.body.weight(.medium))
                    if result.rule.removal == .deletePermanently {
                        Tag(text: "Permanen", tint: .red)
                    } else if result.rule.safety == .review {
                        Tag(text: "Cek dulu", tint: .orange)
                    }
                }
                Text(result.rule.id.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Text(Format.bytes(result.totalSize))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Design.Spacing.xs)
    }
}

private struct JunkItemRow: View {
    let item: JunkItem
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: Design.Spacing.m) {
            SelectionBox(state: isSelected ? .on : .off, action: toggle)
            Text(item.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(Format.path(item.url))
            if item.isInUse {
                Tag(text: "Lagi dipakai")
            }
            Spacer()
            Text(Format.bytes(item.size))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .contextMenu {
            Button("Tampilkan di Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
        }
    }
}

private struct PermissionRow: View {
    let rule: JunkRule
    @Environment(PermissionCenter.self) private var permissions

    var body: some View {
        HStack(spacing: Design.Spacing.m) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.id.title)
                    .font(.body.weight(.medium))
                Text("Butuh Akses Disk Penuh buat ngecek lokasi ini.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Buka Pengaturan") { permissions.openFullDiskAccessSettings() }
        }
        .padding(.vertical, Design.Spacing.xs)
    }
}

private struct FinishedView: View {
    let summary: CleanupSummary
    let onScanAgain: () -> Void
    let onEmptyTrash: () -> Void

    var body: some View {
        VStack(spacing: Design.Spacing.m) {
            Image(systemName: summary.trashNeedsPermission ? "lock.shield" : "checkmark.circle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(summary.trashNeedsPermission ? AnyShapeStyle(.orange) : AnyShapeStyle(.tint))
                .accessibilityHidden(true)
            Text(summary.trashNeedsPermission ? "Butuh izin dulu" : "Beres!")
                .font(.title2.weight(.semibold))
            VStack(spacing: Design.Spacing.xs) {
                if summary.trashNeedsPermission {
                    Text("Buat ngosongin Tong Sampah, Hapus butuh Akses Disk Penuh. Atau kosongin manual lewat Finder.")
                }
                if summary.trashedBytes > 0 {
                    Text(
                        "\(Format.bytes(summary.trashedBytes)) udah dipindah ke Tong Sampah. Kosongin Tong Sampah biar ruangnya beneran lega."
                    )
                }
                if summary.deletedBytes > 0 {
                    Text("\(Format.bytes(summary.deletedBytes)) udah dihapus permanen.")
                }
                if summary.failedCount > 0 {
                    Text("\(summary.failedCount) item dilewati karena lagi dipakai atau butuh izin.")
                }
                if summary == CleanupSummary() {
                    Text("Nggak ada yang perlu dibersihin.")
                }
            }
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 460)
            HStack {
                if summary.trashedBytes > 0 {
                    Button("Kosongin Tong Sampah", action: onEmptyTrash)
                }
                Button("Pindai Lagi", action: onScanAgain)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.top, Design.Spacing.s)
        }
        .padding(Design.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
