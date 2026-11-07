import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case overview, systemJunk, developerJunk, uninstaller, largeFiles, diskUsage, startupItems

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .overview: "Ringkasan"
        case .systemJunk: "Sampah Sistem"
        case .developerJunk: "Sampah Developer"
        case .uninstaller: "Hapus Aplikasi"
        case .largeFiles: "File Gede & Lama"
        case .diskUsage: "Peta Disk"
        case .startupItems: "Jalan Otomatis"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .overview: "Kondisi Mac kamu sekarang."
        case .systemJunk: "Cache, log, dan sisa file yang aman dibuang."
        case .developerJunk: "Sisa build dan cache tool ngoding yang bisa dibikin ulang."
        case .uninstaller: "Buang aplikasi sekalian sama file sisanya."
        case .largeFiles: "Cari file yang makan tempat tapi jarang kamu buka."
        case .diskUsage: "Lihat folder mana yang paling makan tempat."
        case .startupItems: "Program yang jalan sendiri di belakang layar, tanpa kamu buka."
        }
    }

    var symbol: String {
        switch self {
        case .overview: "gauge.with.dots.needle.33percent"
        case .systemJunk: "sparkles"
        case .developerJunk: "hammer"
        case .uninstaller: "square.grid.2x2"
        case .largeFiles: "doc.text.magnifyingglass"
        case .diskUsage: "chart.bar.doc.horizontal"
        case .startupItems: "autostartstop"
        }
    }
}
