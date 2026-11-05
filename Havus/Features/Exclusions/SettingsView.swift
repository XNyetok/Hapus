import AppKit
import SwiftUI

/// Havus → Pengaturan… (⌘,).
struct SettingsView: View {
    var body: some View {
        TabView {
            ExclusionsPane()
                .tabItem { Label("Pengecualian", systemImage: "hand.raised") }
        }
        .frame(width: 540)
    }
}

/// The files and folders Havus never touches.
private struct ExclusionsPane: View {
    @Environment(ExclusionStore.self) private var exclusions
    @State private var selection: Set<URL> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.m) {
            Text(
                "Havus nggak bakal nyentuh file dan folder di sini, termasuk semua isinya. Semuanya nggak muncul di hasil pindai, dan nggak bakal dipindah ke Tong Sampah atau dihapus."
            )
            .fixedSize(horizontal: false, vertical: true)

            List(exclusions.urls, id: \.self, selection: $selection) { url in
                Label {
                    Text(Format.path(url))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(Format.path(url))
                } icon: {
                    FileIcon(url: url, size: 16)
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .frame(height: 220)
            .overlay {
                if exclusions.urls.isEmpty {
                    Text("Belum ada yang dikecualiin.")
                        .foregroundStyle(.secondary)
                }
            }
            .onDeleteCommand(perform: removeSelection)

            HStack(spacing: Design.Spacing.s) {
                Button(action: add) {
                    Image(systemName: "plus")
                }
                .help("Tambah file atau folder")
                .accessibilityLabel("Tambah file atau folder")
                Button(action: removeSelection) {
                    Image(systemName: "minus")
                }
                .help("Hapus dari daftar")
                .accessibilityLabel("Hapus dari daftar")
                .disabled(selection.isEmpty)
            }

            Text("Bisa juga dari hasil pindai: klik kanan sebuah item, lalu pilih **Masukin ke Pengecualian**.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Design.Spacing.xl)
    }

    private func add() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = String(localized: "Pilih file atau folder yang nggak boleh disentuh Havus.")
        panel.prompt = String(localized: "Kecualiin")
        guard panel.runModal() == .OK else { return }
        exclusions.add(panel.urls)
    }

    private func removeSelection() {
        exclusions.remove(selection)
        selection = []
    }
}
