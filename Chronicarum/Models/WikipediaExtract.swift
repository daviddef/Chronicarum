import Foundation

/// Fetches a site's Wikipedia summary at runtime.
///
/// ## Why fetched and never bundled
///
/// Most of the catalogue carries a one-line description or none — the longest-standing
/// open item in the roadmap. Wikipedia has real prose for a large share of it, and the
/// licensing was settled during the Brisbane research:
///
///   * Wikipedia text is **CC BY-SA 4.0**, satisfied by a hyperlink to the page reused.
///   * But §2(a)(5)(B) carries an anti-TPM clause, and Creative Commons' own wiki flags
///     App Store distribution as a possible violation — while explicitly rejecting
///     parallel distribution as a cure.
///
/// Fetching at runtime sidesteps the question rather than arguing with it, and is how the
/// official Wikipedia iOS app works. What ships in the bundle is the article **title**,
/// which comes from Wikidata and is CC0 — an identifier, not the work.
///
/// The title comes from the Wikidata sitelink, never from our own name string:
/// `/page/summary/Maryborough_Post_Office` returns a **disambiguation page**, and
/// title-matching heritage names hits that constantly.
enum WikipediaExtract {

    /// Titles are CC0 identifiers, so these ship in the bundle.
    private static let titlesByQID: [String: String] = {
        guard let url = Bundle.main.url(forResource: "wikipedia_titles", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return table
    }()

    private static var cache: [String: Summary] = [:]
    private static let cacheQueue = DispatchQueue(label: "wikipedia.cache")

    struct Summary {
        let text: String
        let articleURL: URL?
    }

    private struct Response: Decodable {
        let extract: String?
        let content_urls: ContentURLs?
        struct ContentURLs: Decodable {
            let desktop: Page?
            struct Page: Decodable { let page: String? }
        }
    }

    static func title(for site: Site) -> String? {
        guard site.id.hasPrefix("wd-") else { return nil }
        return titlesByQID[String(site.id.dropFirst(3))]
    }

    /// Returns nil when there is no article, no network, or the response is not usable.
    /// Never throws into the UI — a missing summary is a normal state, not an error.
    static func summary(for site: Site) async -> Summary? {
        guard let title = title(for: site) else { return nil }

        if let cached = cacheQueue.sync(execute: { cache[title] }) { return cached }

        guard let encoded = title.addingPercentEncoding(
                withAllowedCharacters: .urlPathAllowed),
              let url = URL(string:
                "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)")
        else { return nil }

        var request = URLRequest(url: url)
        // Wikimedia's policy: an identifying User-Agent lifts the limit from 10 requests
        // a minute to 200. Without one this would rate-limit almost immediately.
        request.setValue("Chronicarum/1.0 (https://github.com/daviddef/Chronicarum)",
                         forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let extract = decoded.extract,
              !extract.isEmpty
        else { return nil }

        let summary = Summary(
            text: extract,
            articleURL: decoded.content_urls?.desktop?.page.flatMap(URL.init(string:)))
        cacheQueue.sync { cache[title] = summary }
        return summary
    }
}
