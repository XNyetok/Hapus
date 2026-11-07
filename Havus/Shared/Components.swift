import SwiftUI

/// Large title plus a one-line explanation, at the top of every page.
struct PageHeader: View {
    let item: SidebarItem

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.xs) {
            Text(item.title)
                .font(.largeTitle.weight(.semibold))
            Text(item.subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Subtle rounded surface for grouped content.
private struct CardBackground: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Design.surface, in: RoundedRectangle(cornerRadius: Design.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Design.Radius.card, style: .continuous)
                    .strokeBorder(Design.hairline)
            }
    }
}

extension View {
    func card(padding: CGFloat = Design.Spacing.l) -> some View {
        modifier(CardBackground(padding: padding))
    }
}

/// Bottom bar with a page's summary on the left and its primary action on the right.
struct ActionBar<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Design.Spacing.m) {
            leading
            Spacer(minLength: Design.Spacing.m)
            trailing
        }
        .padding(.horizontal, Design.Spacing.xl)
        .padding(.vertical, Design.Spacing.m)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

/// Centered message with an optional primary action.
struct MessageView: View {
    let symbol: String
    var symbolTint: Color?
    let title: LocalizedStringKey
    let message: Text
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Design.Spacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(symbolTint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.tint))
                .padding(.bottom, Design.Spacing.s)
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.weight(.semibold))
            message
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .padding(.top, Design.Spacing.s)
            }
        }
        .padding(Design.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum CheckState {
    case on, off, mixed

    /// What VoiceOver says after the row, e.g. "Cache npm, 1,2 GB, Dipilih".
    var accessibilityValue: LocalizedStringKey {
        switch self {
        case .on: "Dipilih"
        case .off: "Nggak dipilih"
        case .mixed: "Sebagian dipilih"
        }
    }
}

/// Checkbox that can also show a mixed state, for "everything in this group".
/// VoiceOver skips the box itself: put `selectableRow(_:toggle:)` on the row around it.
struct SelectionBox: View {
    let state: CheckState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(state == .off ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }

    private var symbol: String {
        switch state {
        case .on: "checkmark.square.fill"
        case .off: "square"
        case .mixed: "minus.square.fill"
        }
    }
}

extension View {
    /// Makes a row with a `SelectionBox` read as one checkbox in VoiceOver: its name, details and size,
    /// then the selection state. Without it, every box in a list only said "Pilih", with no item name.
    func selectableRow(_ state: CheckState, toggle: @escaping () -> Void) -> some View {
        accessibilityElement(children: .combine)
            .accessibilityValue(state.accessibilityValue)
            .accessibilityAddTraits(.isToggle)
            .accessibilityAction { toggle() }
    }

    /// The same for a `DisclosureGroup` label. VoiceOver's default action on the label already opens or closes
    /// the group, and a second default action would fire together with it, so selecting the group is a named action.
    func selectableGroupLabel(_ state: CheckState, toggleAll: @escaping () -> Void) -> some View {
        accessibilityElement(children: .combine)
            .accessibilityValue(state.accessibilityValue)
            .accessibilityAction(named: state == .on ? "Batal pilih semua" : "Pilih semua") { toggleAll() }
    }
}

/// Small capsule label, e.g. "Cek dulu".
struct Tag: View {
    let text: LocalizedStringKey
    var tint: Color = .secondary
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            // In light mode, orange and red text on the pale capsule reads at only about 2:1 and 3:1, so darken it there.
            .brightness(colorScheme == .light ? -0.3 : 0)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

/// Card with an icon, a title, a short explanation and a row of buttons, such as the Full Disk Access banner.
struct NoticeCard<Actions: View>: View {
    let symbol: String
    var tint: Color = .accentColor
    let title: Text
    let message: Text
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .top, spacing: Design.Spacing.m) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Design.Spacing.xs) {
                title
                    .font(.headline)
                message
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack { actions }
                    .padding(.top, Design.Spacing.xs)
            }
            Spacer(minLength: 0)
        }
        .card()
    }
}

/// Explains why Full Disk Access helps, and links to System Settings. Hidden once granted.
struct FullDiskAccessBanner: View {
    @Environment(PermissionCenter.self) private var permissions

    var body: some View {
        if !permissions.hasFullDiskAccess {
            NoticeCard(
                symbol: "lock.shield",
                tint: .orange,
                title: Text("Akses Disk Penuh belum aktif"),
                message: Text(
                    "Tanpa izin ini, beberapa lokasi (kayak Tong Sampah, lampiran Mail, dan data app lain) bakal dilewati. Buka **Privacy & Security → Full Disk Access**, terus nyalain Havus."
                )
            ) {
                Button("Buka Pengaturan") { permissions.openFullDiskAccessSettings() }
                Button("Cek Lagi") { permissions.refresh() }
            }
        }
    }
}

/// A size, or what Havus knows about it when it couldn't read everything, instead of looking empty ("0 byte").
struct SizeText: View {
    let bytes: Int64
    /// `false` when Havus couldn't read all of it, so `bytes` is only what it could read.
    let isComplete: Bool

    var body: some View {
        if isComplete {
            Text(Format.bytes(bytes))
        } else if bytes == 0 {
            Text("Nggak kebaca")
                .help("macOS nggak ngizinin Havus baca isinya, jadi ukurannya belum ketahuan.")
        } else {
            Text(verbatim: "\(Format.bytes(bytes))+")
                .help("Sebagian isinya nggak bisa dibaca Havus, jadi ukuran aslinya bisa lebih gede.")
                .accessibilityLabel("Lebih dari \(Format.bytes(bytes))")
        }
    }
}

/// App icon as Finder shows it.
struct FileIcon: View {
    let url: URL
    let size: CGFloat

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false)))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
