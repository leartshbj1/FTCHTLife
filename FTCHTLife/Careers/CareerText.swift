import Foundation

/// Accords en genre des textes du module.
/// Les données utilisent l'écriture « Directeur·rice », « Joueur·se », « élu·e·s » ;
/// on les résout selon le genre du personnage, pour obtenir « Directrice » ou « Directeur ».
enum CareerText {
    private static let regex = try? NSRegularExpression(pattern: "(\\w+)·(\\w+)(?:·(\\w+))?", options: [])

    static func resolveGender(_ text: String, female: Bool) -> String {
        guard text.contains("·"), let regex = regex else { return text }
        let ns = text as NSString
        var result = ""
        var last = 0
        for m in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let base = ns.substring(with: m.range(at: 1))
            let suffix = ns.substring(with: m.range(at: 2))
            let plural = m.range(at: 3).location == NSNotFound ? "" : ns.substring(with: m.range(at: 3))
            result += (female ? feminine(base, suffix) : base) + plural
            last = m.range.location + m.range.length
        }
        result += ns.substring(from: last)
        return result
    }

    static func feminine(_ base: String, _ suffix: String) -> String {
        switch suffix {
        case "rice" where base.hasSuffix("teur"):
            return String(base.dropLast(3)) + "rice"          // Directeur → Directrice
        case "se" where base.hasSuffix("eur"):
            return String(base.dropLast(1)) + "se"            // Joueur → Joueuse
        case "ère" where base.hasSuffix("er"), "e" where base.hasSuffix("er"):
            return String(base.dropLast(2)) + "ère"           // Conseiller → Conseillère, premier → première
        case "e", "ne", "fe", "le", "te":
            return base + suffix                              // Candidat → Candidate, Champion → Championne
        default:
            return base + suffix
        }
    }
}
