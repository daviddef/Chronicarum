import Foundation

/// Descriptive prose for French monuments historiques, from the Mérimée register.
///
/// This is the first bulk source that ships real writing rather than a one-line label —
/// 23,811 passages, ~525 characters at the median — so it is also the first partial answer
/// to the catalogue being a wall of bare pins.
///
/// The text is French and stays French. It is the French state's own description of a
/// French monument, published under Licence Ouverte; machine-translating it would produce
/// an adaptation of an official record, and a mistranslated protection notice is worse
/// than an untranslated one. The UI says which language it is in rather than pretending
/// otherwise.
enum MonumentHistory {

    /// ~14 MB, so it loads on first use and never on the launch path — a detail sheet
    /// needs it, the map and Explore list never do. Same split as `PhotoCredits`.
    private static let byID: [String: String] = {
        guard let url = Bundle.main.url(forResource: "merimee_history", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return table
    }()

    static func history(for id: String) -> String? {
        let text = byID[id]
        return text?.isEmpty == false ? text : nil
    }
}

extension Site {
    /// The register's own account of this monument, when there is one.
    var monumentHistory: String? { MonumentHistory.history(for: id) }
}
