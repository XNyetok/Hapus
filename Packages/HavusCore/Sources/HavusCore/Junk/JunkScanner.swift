import Foundation

public struct JunkItem: Sendable, Hashable, Identifiable {
    public let ruleID: JunkRule.ID
    /// What the user sees: a child folder, or the rule's whole location.
    public let url: URL
    /// What actually gets removed. For `.wholeContents` rules these are the location's children.
    public let removalTargets: [URL]
    public let size: Int64
    /// Named after an app that is running right now.
    public let isInUse: Bool

    public var id: URL { url }
    public var name: String { url.lastPathComponent }
}

public struct JunkScanResult: Sendable, Identifiable {
    public enum Status: Sendable, Hashable {
        case ok
        case notFound
        case noPermission
    }

    public let rule: JunkRule
    public let status: Status
    public let items: [JunkItem]

    public var id: JunkRule.ID { rule.id }
    public var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }

    /// The same result without the items `exclusions` blocks, for exclusions added after the scan.
    ///
    /// An item goes away as a whole when any of its removal targets is blocked: its size covers all of them, so a
    /// new scan is what brings back the rest.
    public func excluding(_ exclusions: ExclusionList) -> JunkScanResult {
        guard !exclusions.isEmpty else { return self }
        let kept = items.filter { !$0.removalTargets.contains(where: exclusions.blocks) }
        return JunkScanResult(rule: rule, status: status, items: kept)
    }
}

public struct JunkScanner: Sendable {
    public let home: URL
    public let rules: [JunkRule]

    /// Names that are never worth listing.
    static let ignoredNames: Set<String> = [".DS_Store", ".localized"]

    public init(home: URL = .homeDirectory, rules: [JunkRule] = JunkRule.catalog) {
        self.home = home
        self.rules = rules
    }

    /// Blocking. Call from a background task.
    /// - Parameters:
    ///   - inUseNames: Bundle identifiers of running apps; matching items start unselected.
    ///   - exclusions: Entries they block are left out, and aren't measured either.
    public func scan(
        _ rule: JunkRule, inUseNames: Set<String> = [], excluding exclusions: ExclusionList = ExclusionList()
    ) -> JunkScanResult {
        let location = rule.location(in: home)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: location.path(percentEncoded: false), isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            return JunkScanResult(rule: rule, status: .notFound, items: [])
        }

        let children: [URL]
        do {
            let claimed = claimedNames(for: rule)
            children = try FileManager.default.contentsOfDirectory(
                at: location, includingPropertiesForKeys: nil, options: []
            ).filter { child in
                let name = child.lastPathComponent
                return !Self.ignoredNames.contains(name) && !rule.excludedNames.contains(name)
                    && !claimed.contains(name) && !exclusions.blocks(child)
            }
        } catch {
            return JunkScanResult(rule: rule, status: .noPermission, items: [])
        }

        switch rule.strategy {
        case .eachChild:
            var items: [JunkItem] = []
            for child in children {
                if Task.isCancelled { break }
                let size = DirectorySize.allocatedSize(of: child)
                guard size > 0 else { continue }
                items.append(
                    JunkItem(
                        ruleID: rule.id, url: child, removalTargets: [child], size: size,
                        isInUse: inUseNames.contains(child.lastPathComponent)))
            }
            return JunkScanResult(rule: rule, status: .ok, items: items.sorted { $0.size > $1.size })

        case .wholeContents:
            var size: Int64 = 0
            for child in children {
                if Task.isCancelled { break }
                size += DirectorySize.allocatedSize(of: child)
            }
            guard size > 0 else { return JunkScanResult(rule: rule, status: .ok, items: []) }
            let item = JunkItem(
                ruleID: rule.id, url: location, removalTargets: children, size: size, isInUse: false)
            return JunkScanResult(rule: rule, status: .ok, items: [item])
        }
    }

    /// Direct children owned by a more specific rule, e.g. `Homebrew` inside `Library/Caches`.
    /// Those are listed under their own rule so nothing is counted twice.
    func claimedNames(for rule: JunkRule) -> Set<String> {
        let parent = rule.relativePath.split(separator: "/")
        return Set(
            rules.compactMap { other in
                let components = other.relativePath.split(separator: "/")
                guard other.id != rule.id, components.count == parent.count + 1, components.starts(with: parent)
                else { return nil }
                return components.last.map(String.init)
            })
    }
}
