import HavusCore
import SwiftUI

/// UI text for every built-in rule. The switch is exhaustive, so a new rule can't ship without copy.
extension JunkRule.ID {
    var title: LocalizedStringKey {
        switch self {
        case .userCaches: "Cache aplikasi"
        case .userLogs: "Log aplikasi"
        case .mailDownloads: "Lampiran Mail yang pernah dibuka"
        case .iPhoneSoftwareUpdates: "File update iPhone"
        case .iPadSoftwareUpdates: "File update iPad"
        case .trash: "Isi Tong Sampah"
        case .xcodeDerivedData: "Xcode DerivedData"
        case .xcodeArchives: "Arsip Xcode"
        case .xcodeDeviceSupport: "iOS Device Support"
        case .xcodePreviews: "Cache SwiftUI Previews"
        case .simulatorCaches: "Cache Simulator"
        case .homebrewCache: "Cache Homebrew"
        case .npmCache: "Cache npm"
        case .yarnCache: "Cache Yarn"
        case .pnpmCache: "Cache pnpm"
        case .cocoaPodsCache: "Cache CocoaPods"
        case .swiftPMCache: "Cache Swift Package Manager"
        case .pipCache: "Cache pip"
        case .goBuildCache: "Cache build Go"
        case .gradleCache: "Cache Gradle"
        case .bunCache: "Cache Bun"
        case .cargoRegistryCache: "Cache Cargo"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .userCaches:
            "File sementara biar app kebuka lebih cepat. Aman dihapus, nanti dibikin ulang otomatis."
        case .userLogs:
            "Catatan aktivitas dan laporan crash dari app. Biasanya cuma kepake buat debugging."
        case .mailDownloads:
            "Salinan lampiran yang pernah kamu buka dari Mail. Lampiran aslinya tetap ada di email."
        case .iPhoneSoftwareUpdates:
            "Installer iOS (.ipsw) yang udah kepake. Bakal diunduh ulang kalau dibutuhin."
        case .iPadSoftwareUpdates:
            "Installer iPadOS (.ipsw) yang udah kepake. Bakal diunduh ulang kalau dibutuhin."
        case .trash:
            "Dihapus permanen, nggak bisa dibalikin. Cek dulu isinya ya."
        case .xcodeDerivedData:
            "Hasil build dan index Xcode. Dibikin ulang pas kamu build lagi."
        case .xcodeArchives:
            "Hasil archive app, termasuk dSYM buat baca crash report. Hapus yang udah nggak kamu butuhin aja."
        case .xcodeDeviceSupport:
            "Simbol debug per versi iOS. Disalin ulang pas device dicolok, tapi lumayan lama."
        case .xcodePreviews:
            "Simulator khusus SwiftUI Previews. Dibikin ulang otomatis."
        case .simulatorCaches:
            "Cache dan data sementara dari CoreSimulator."
        case .homebrewCache:
            "File unduhan formula dan cask, sama kayak `brew cleanup`."
        case .npmCache:
            "Paket npm yang di-cache. Diunduh ulang kalau dibutuhin."
        case .yarnCache:
            "Paket Yarn yang di-cache. Diunduh ulang kalau dibutuhin."
        case .pnpmCache:
            "Metadata cache pnpm. Store utamanya nggak disentuh."
        case .cocoaPodsCache:
            "Pod dan spec yang di-cache."
        case .swiftPMCache:
            "Repo dan manifest paket Swift yang di-cache."
        case .pipCache:
            "Paket Python yang di-cache."
        case .goBuildCache:
            "Hasil build Go yang di-cache, sama kayak `go clean -cache`."
        case .gradleCache:
            "Dependency dan hasil build Gradle yang di-cache."
        case .bunCache:
            "Paket Bun yang di-cache."
        case .cargoRegistryCache:
            "File .crate dari registry Rust yang di-cache."
        }
    }
}
