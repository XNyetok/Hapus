import HavusCore
import SwiftUI

/// "Peta Disk": the folders and files in the home folder, biggest first, each with a bar for its share of the
/// folder on screen. Click a folder to see inside it. Read-only.
struct DiskUsageView: View {
    let model: DiskUsageModel
    @Environment(PermissionCenter.self) private var permissions

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(item: .diskUsage)
                .padding([.horizontal, .top], Design.Spacing.xxl)
                .padding(.bottom, Design.Spacing.l)
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            MessageView(
                symbol: SidebarItem.diskUsage.symbol,
                title: "Lihat ke mana ruang disk kamu",
                message: Text(
                    "Havus ngitung ukuran tiap folder di folder home kamu, termasuk yang tersembunyi. Cuma dilihat, nggak ada yang dihapus."
                ),
                actionTitle: "Pindai Sekarang"
            ) { model.scan() }

        case .scanning:
            VStack(spacing: Design.Spacing.m) {
                ProgressView()
                Text("Lagi ngitung ukuran folder…")
                    .foregroundStyle(.secondary)
                if let progress = model.progress {
                    Text("\(Format.bytes(progress.bytes)) udah dihitung")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Button("Batal") { model.cancel() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .results:
            if let folder = model.current {
                results(folder)
            }
        }
    }

    private func results(_ folder: DiskUsageItem) -> some View {
        VStack(spacing: 0) {
            if model.root?.isComplete == false, !permissions.hasFullDiskAccess {
                FullDiskAccessBanner()
                    .padding(.horizontal, Design.Spacing.xxl)
                    .padding(.bottom, Design.Spacing.l)
            }
            List {
                Section {
                    contents(of: folder)
                } header: {
                    FolderHeader(model: model, folder: folder)
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .contentMargins(.horizontal, Design.Spacing.l, for: .scrollContent)
            // A new folder starts at the top of the list.
            .id(folder.id)

            ActionBar {
                Text(
                    "Di sini cuma buat ngelihat. Buat bersihin, pakai **Sampah Sistem**, **Sampah Developer**, atau **File Gede & Lama**."
                )
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            } trailing: {
                Button("Pindai Ulang") { model.scan() }
            }
        }
    }

    @ViewBuilder
    private func contents(of folder: DiskUsageItem) -> some View {
        let children = folder.children ?? []
        if children.isEmpty, folder.otherItems.count == 0 {
            Group {
                if folder.isComplete {
                    Text("Folder ini kosong.")
                } else {
                    Text("macOS nggak ngizinin Havus baca isi folder ini.")
                }
            }
            .foregroundStyle(.secondary)
        } else {
            ForEach(children) { item in
                row(item, share: share(item.bytes, of: folder))
            }
            if folder.otherItems.count > 0 {
                OtherItemsRow(other: folder.otherItems, share: share(folder.otherItems.bytes, of: folder))
            }
        }
    }

    @ViewBuilder
    private func row(_ item: DiskUsageItem, share: Double) -> some View {
        let row = DiskUsageRow(
            item: item, share: share, isExcluded: model.isExcluded(item), isOpening: model.opening == item.id)
        Group {
            if item.kind == .folder {
                Button {
                    model.open(item)
                } label: {
                    row
                }
                .buttonStyle(.plain)
                .accessibilityHint("Buka folder ini")
            } else {
                row
            }
        }
        .contextMenu {
            if item.kind == .folder {
                Button("Buka") { model.open(item) }
            }
            Button("Tampilkan di Finder") { model.reveal(item) }
        }
    }

    private func share(_ bytes: Int64, of folder: DiskUsageItem) -> Double {
        folder.bytes > 0 ? Double(bytes) / Double(folder.bytes) : 0
    }
}

/// Where the user is, with a way back up, and how big the folder on screen is.
private struct FolderHeader: View {
    let model: DiskUsageModel
    let folder: DiskUsageItem

    var body: some View {
        HStack(spacing: Design.Spacing.s) {
            if model.path.count > 1 {
                Button {
                    model.goUp()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .keyboardShortcut(.upArrow, modifiers: .command)
                .help("Balik ke folder di atasnya")
                .accessibilityLabel("Balik")
            }
            Breadcrumb(path: model.path) { model.goBack(to: $0) }
            Spacer(minLength: Design.Spacing.m)
            SizeText(bytes: folder.bytes, isComplete: folder.isComplete)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .font(.title3)
        .padding(.bottom, Design.Spacing.s)
    }
}

/// The folders from the home folder down to the one on screen. Leaves out the middle ones when they don't fit.
private struct Breadcrumb: View {
    let path: [DiskUsageItem]
    let goTo: (Int) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            crumbs(path.indices.map { $0 })
            if path.count > 3 {
                crumbs([0, nil] + path.indices.suffix(2).map { $0 })
            }
            crumbs([path.count - 1])
        }
    }

    /// `nil` stands for the folders left out.
    private func crumbs(_ indices: [Int?]) -> some View {
        HStack(spacing: Design.Spacing.xs) {
            ForEach(Array(indices.enumerated()), id: \.offset) { position, index in
                if position > 0 {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                if let index {
                    crumb(index)
                } else {
                    Text(verbatim: "…")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
        }
        .fixedSize()
    }

    @ViewBuilder
    private func crumb(_ index: Int) -> some View {
        let name = path[index].name
        if index == path.count - 1 {
            Text(name)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
        } else {
            Button(name) { goTo(index) }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
        }
    }
}

private struct DiskUsageRow: View {
    let item: DiskUsageItem
    let share: Double
    let isExcluded: Bool
    let isOpening: Bool

    var body: some View {
        HStack(spacing: Design.Spacing.m) {
            FileIcon(url: item.url, size: 24)
            HStack(spacing: Design.Spacing.s) {
                Text(item.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if isExcluded {
                    Tag(text: "Dikecualiin")
                }
            }
            Spacer(minLength: Design.Spacing.m)
            ShareBar(share: share)
                .frame(width: 120)
            SizeText(bytes: item.bytes, isComplete: item.isComplete)
                .monospacedDigit()
                .frame(minWidth: 80, alignment: .trailing)
            disclosure
                .frame(width: 16)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .help(Format.path(item.url))
        .accessibilityElement(children: .combine)
        .accessibilityValue(Format.percent(share))
    }

    @ViewBuilder
    private var disclosure: some View {
        if isOpening {
            ProgressView()
                .controlSize(.small)
        } else if item.kind == .folder {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        } else {
            Color.clear
        }
    }
}

/// The smaller items of a folder, added up in one row so the list stays short.
private struct OtherItemsRow: View {
    let other: DiskUsageItem.OtherItems
    let share: Double

    var body: some View {
        HStack(spacing: Design.Spacing.m) {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            Text("\(other.count) item lain")
                .foregroundStyle(.secondary)
            Spacer(minLength: Design.Spacing.m)
            ShareBar(share: share, tint: .secondary)
                .frame(width: 120)
            Text(Format.bytes(other.bytes))
                .monospacedDigit()
                .frame(minWidth: 80, alignment: .trailing)
            Color.clear
                .frame(width: 16)
        }
        .padding(.vertical, 2)
        .help("Item yang lebih kecil, digabung biar daftarnya nggak kepanjangan.")
        .accessibilityElement(children: .combine)
        .accessibilityValue(Format.percent(share))
    }
}

/// An item's share of the folder on screen: a thin bar on a lighter track of the same hue, square where it starts
/// and rounded where it ends. The size next to it carries the number, so the bar needs no label.
private struct ShareBar: View {
    let share: Double
    var tint: Color = .accentColor

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                bar.fill(tint.opacity(0.15))
                if share > 0 {
                    // Never thinner than 2 points, so a tiny share still shows up.
                    bar.fill(tint)
                        .frame(width: max(2, geometry.size.width * min(share, 1)))
                }
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }

    private var bar: UnevenRoundedRectangle {
        UnevenRoundedRectangle(cornerRadii: .init(bottomTrailing: 4, topTrailing: 4), style: .continuous)
    }
}
