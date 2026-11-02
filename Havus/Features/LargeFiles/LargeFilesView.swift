import HavusCore
import SwiftUI

struct LargeFilesView: View {
    @Bindable var model: LargeFilesModel
    @State private var isConfirming = false

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(item: .largeFiles)
                .padding([.horizontal, .top], Design.Spacing.xxl)
                .padding(.bottom, Design.Spacing.l)
            filters
                .padding(.horizontal, Design.Spacing.xxl)
                .padding(.bottom, Design.Spacing.l)
            content
        }
        .confirmationDialog(
            Text("Pindahin \(model.selectedFiles.count) file ke Tong Sampah?"), isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button("Pindahin \(Format.bytes(model.selectedSize))", role: .destructive) { model.moveSelectionToTrash() }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("File masih bisa dibalikin dari Tong Sampah sampai kamu ngosonginnya.")
        }
    }

    private var filters: some View {
        HStack(spacing: Design.Spacing.l) {
            Picker("Ukuran minimal", selection: $model.minimumSize) {
                ForEach(LargeFilesModel.MinimumSize.allCases) { size in
                    Text(size.label).tag(size)
                }
            }
            .fixedSize()
            Picker("Terakhir dibuka", selection: $model.lastOpened) {
                ForEach(LargeFilesModel.LastOpened.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .fixedSize()
            Spacer()
            if model.phase != .idle {
                Button("Cari Ulang") { model.search() }
                    .disabled(model.phase == .searching || model.phase == .removing)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            MessageView(
                symbol: "doc.text.magnifyingglass",
                title: "Cari file yang makan tempat",
                message: Text(
                    "Havus pakai index Spotlight buat nyari file gede di folder kamu (di luar Library). Nggak ada yang dihapus tanpa persetujuan kamu."
                ),
                actionTitle: "Cari Sekarang"
            ) { model.search() }

        case .searching:
            VStack(spacing: Design.Spacing.m) {
                ProgressView()
                Text("Lagi nyari file gede…")
                    .foregroundStyle(.secondary)
                Button("Batal") { model.cancel() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .results, .removing:
            if model.files.isEmpty {
                MessageView(
                    symbol: "checkmark.seal", title: "Nggak ada yang cocok",
                    message: Text("Coba turunin ukuran minimal atau ganti filter terakhir dibuka."))
            } else {
                results
            }
        }
    }

    private var results: some View {
        VStack(spacing: 0) {
            List {
                if let removal = model.lastRemoval {
                    Label(
                        removal.failedCount > 0
                            ? "\(removal.count) file (\(Format.bytes(removal.bytes))) dipindah ke Tong Sampah, \(removal.failedCount) gagal."
                            : "\(removal.count) file (\(Format.bytes(removal.bytes))) udah dipindah ke Tong Sampah.",
                        systemImage: "checkmark.circle"
                    )
                    .foregroundStyle(.secondary)
                }
                Section {
                    ForEach(model.files) { file in
                        LargeFileRow(file: file, isSelected: model.selection.contains(file.id)) { model.toggle(file) }
                            .contextMenu {
                                Button("Tampilkan di Finder") { model.reveal(file) }
                                Button("Buka") { model.open(file) }
                            }
                    }
                } header: {
                    Text("\(model.files.count) file · \(Format.bytes(model.totalSize))")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.bottom, Design.Spacing.s)
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .contentMargins(.horizontal, Design.Spacing.l, for: .scrollContent)

            ActionBar {
                Text("\(model.selection.count) file dipilih · \(Format.bytes(model.selectedSize))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } trailing: {
                Button("Pindahin ke Tong Sampah") { isConfirming = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.selection.isEmpty || model.phase == .removing)
            }
        }
    }
}

private struct LargeFileRow: View {
    let file: LargeFile
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: Design.Spacing.m) {
            SelectionBox(state: isSelected ? .on : .off, action: toggle)
            FileIcon(url: file.url, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(Format.path(file.url.deletingLastPathComponent()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            lastUsed
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(Format.bytes(file.size))
                .monospacedDigit()
                .frame(minWidth: 72, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }

    private var lastUsed: Text {
        if let date = file.lastOpened {
            Text("Dibuka \(Format.relativeDate(date))")
        } else if let date = file.modified {
            Text("Diubah \(Format.relativeDate(date))")
        } else {
            Text(verbatim: "–")
        }
    }
}

extension LargeFilesModel.LastOpened {
    var label: LocalizedStringKey {
        switch self {
        case .any: "Kapan aja"
        case .threeMonths: "Lebih dari 3 bulan lalu"
        case .sixMonths: "Lebih dari 6 bulan lalu"
        case .oneYear: "Lebih dari 1 tahun lalu"
        }
    }
}
