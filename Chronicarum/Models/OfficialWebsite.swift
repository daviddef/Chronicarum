import Foundation

/// Official websites for sites that have one, so a reader can check opening hours
/// themselves — the app cannot tell them.
///
/// Coverage is 6,871 of 260,008 sites (2.6%), from Wikidata `P856` (CC0). Thin, and
/// shipped anyway: the alternative for those sites is "go and find out somehow". The
/// wider problem is documented in `OpeningPattern` — there is no source for hours, and
/// the only candidate with real coverage would cost an ODbL publication obligation to buy
/// 5%.
enum OfficialWebsite {

    /// Loaded on first use, like the photo credits — a detail sheet needs it, the map
    /// never does.
    private static let byQID: [String: String] = {
        guard let url = Bundle.main.url(forResource: "websites", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return table
    }()

    static func url(for site: Site) -> URL? {
        guard site.id.hasPrefix("wd-") else { return nil }
        let qid = String(site.id.dropFirst(3))
        guard let raw = byQID[qid] else { return nil }
        return URL(string: raw)
    }
}

extension Site {
    var officialWebsite: URL? { OfficialWebsite.url(for: self) }
}
