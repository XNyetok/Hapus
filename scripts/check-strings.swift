// Checks a String Catalog: every string has an English translation, and none is left over from removed code.
//
// Usage: swift scripts/check-strings.swift <path/to/Localizable.xcstrings>
// Usually run through scripts/check-strings.sh, which first syncs the catalog with the strings in the code.

import Foundation

let path = CommandLine.arguments.dropFirst().first ?? "Havus/Localizable.xcstrings"

guard
    let data = FileManager.default.contents(atPath: path),
    let catalog = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
    let strings = catalog["strings"] as? [String: [String: Any]]
else {
    print("error: can't read the string catalog at \(path)")
    exit(1)
}

/// True when a localization, plural form or substitution has text and all of it is translated.
func isTranslated(_ node: Any?) -> Bool {
    guard let node = node as? [String: Any] else { return false }
    var texts = 0
    if let unit = node["stringUnit"] as? [String: Any] {
        guard unit["state"] as? String == "translated" else { return false }
        texts += 1
    }
    for forms in (node["variations"] as? [String: [String: Any]] ?? [:]).values {
        for form in forms.values {
            guard isTranslated(form) else { return false }
            texts += 1
        }
    }
    for substitution in (node["substitutions"] as? [String: Any] ?? [:]).values {
        guard isTranslated(substitution) else { return false }
    }
    return texts > 0
}

/// A format specifier such as `%@`, `%2$lld` or `%#@files@`. Group 1 is the argument number, if any.
let specifier: NSRegularExpression = {
    do {
        return try NSRegularExpression(pattern: #"%(\d+\$)?(#@\w+@|@|lld|ld|llu|lu|d|u|f)"#)
    } catch {
        fatalError("invalid format specifier pattern: \(error)")
    }
}()

/// True when an English text with plural substitutions also has an unnumbered argument, such as
/// `Moved %@%#@leftovers@ to the Trash (%@).` Mixing numbered and unnumbered arguments shows the wrong values or crashes.
func mixesArguments(_ english: Any?) -> Bool {
    guard
        let english = english as? [String: Any], english["substitutions"] != nil,
        let value = (english["stringUnit"] as? [String: Any])?["value"] as? String
    else { return false }
    let matches = specifier.matches(in: value, range: NSRange(value.startIndex..., in: value))
    return matches.contains { match in
        let isSubstitution = Range(match.range(at: 2), in: value).map { value[$0].hasPrefix("#@") } ?? false
        return !isSubstitution && match.range(at: 1).location == NSNotFound
    }
}

var unused: [String] = []
var untranslated: [String] = []
var unnumbered: [String] = []
for (key, entry) in strings.sorted(by: { $0.key < $1.key }) {
    if entry["shouldTranslate"] as? Bool == false { continue }
    let english = (entry["localizations"] as? [String: Any])?["en"]
    if entry["extractionState"] as? String == "stale" {
        unused.append(key)
    } else if !isTranslated(english) {
        untranslated.append(key)
    } else if mixesArguments(english) {
        unnumbered.append(key)
    }
}

for key in untranslated { print("error: no English translation for \"\(key)\"") }
for key in unnumbered {
    print("error: the English for \"\(key)\" varies by plural, so number its other arguments, such as %1$@ and %3$@")
}
for key in unused { print("error: \"\(key)\" isn't used in the code anymore") }

if untranslated.isEmpty && unused.isEmpty && unnumbered.isEmpty {
    print("All \(strings.count) strings have English.")
    exit(0)
}
if !untranslated.isEmpty {
    print(
        "Add the English text to Havus/Localizable.xcstrings in Xcode's String Catalog editor. A new string shows up there after a build in Xcode, or after make strings."
    )
}
if !unused.isEmpty {
    print("Delete strings the code no longer uses from Havus/Localizable.xcstrings.")
}
exit(1)
