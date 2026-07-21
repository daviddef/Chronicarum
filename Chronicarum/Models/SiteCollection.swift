import Foundation
import CoreLocation

/// A finite set of places worth completing.
///
/// The retention research in ROADMAP.md is blunt about why this is bounded rather than a
/// points score. Foursquare removed its own gamification and explained that points were
/// arbitrary across heterogeneous places and that hundreds of badges made badges stop
/// feeling special; open-ended scoring over 294,820 sites would be exactly that. What is
/// documented to work is a finite set where 100% means something — the National Park
/// Passport, which exists to push visitors toward the places they would otherwise skip.
///
/// Built offline by `scripts/derive_collections.py`, which is also where the reasoning
/// about what counts as a legitimate set lives.
struct SiteCollection: Identifiable, Decodable {

    enum Kind: String, Decodable {
        case worldHeritage
        case place
    }

    let id: String
    let kind: Kind
    let title: String
    let blurb: String
    /// The country or locality this belongs to, used to decide whether to show it.
    let region: String
    /// For World Heritage only: how many inscriptions the country actually has.
    ///
    /// Not the same as `siteIDs.count` — the UK has 36 and the catalogue holds 31. Showing
    /// 31 alone would quietly claim that is the whole list, so the real figure travels with
    /// the collection and the app says what is missing rather than hiding it.
    let unescoTotal: Int?
    /// Raw membership as generated. Resolve through `SiteCollectionStore` rather than using
    /// this directly — it has not been filtered for sensitive sites.
    let siteIDs: [String]

    private enum CodingKeys: String, CodingKey {
        case id, kind, title, blurb, region, unescoTotal
        case siteIDs = "sites"
    }
}

/// The resolved form: real sites, with anything unsuitable already removed.
struct ResolvedCollection: Identifiable {
    let collection: SiteCollection
    let sites: [Site]
    /// How many members the catalogue holds but `isSensitive` removed.
    ///
    /// Kept separate from `missingFromCatalogue` because the two have completely different
    /// causes and lumping them together would be a lie in one direction or the other.
    /// Auschwitz is on UNESCO's list and *is* in the catalogue; it is not in this
    /// collection because asking someone to tick it off is grotesque. The Etruscan
    /// Necropolises are dropped by the same rule, which over-includes on purpose. Either
    /// way, "not in Chronicarum yet" would be false.
    let excludedAsSensitive: Int

    var id: String { collection.id }
    var title: String { collection.title }
    var blurb: String { collection.blurb }
    var total: Int { sites.count }

    /// The mean position of the members, for deciding what is near you.
    let centre: CLLocationCoordinate2D

    func visitedCount(in visitedIDs: Set<String>) -> Int {
        sites.reduce(0) { $0 + (visitedIDs.contains($1.id) ? 1 : 0) }
    }

    /// How many of the country's World Heritage Sites the catalogue does not yet hold.
    /// Zero for everything else.
    var missingFromCatalogue: Int {
        guard let unescoTotal = collection.unescoTotal else { return 0 }
        return max(0, unescoTotal - sites.count - excludedAsSensitive)
    }
}

enum SiteCollectionStore {

    /// Every collection, resolved and filtered, in the order the generator produced.
    ///
    /// **Sensitive sites are removed here and nowhere else.** `Site.isSensitive` covers
    /// death camps, massacre sites, plantations and burial grounds, and it is the guard
    /// that keeps them away from anything playful — Pokémon GO put capture points at
    /// Auschwitz and Hiroshima, which is the documented version of getting this wrong. The
    /// generator deliberately does not apply it: a second copy of that logic in Python
    /// could drift from this one, and drift here means inviting somebody to tick off a
    /// genocide memorial. Filtering at load keeps one implementation and makes the totals
    /// shown agree with it by construction.
    static let all: [ResolvedCollection] = {
        guard let url = Bundle.main.url(forResource: "collections", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([SiteCollection].self, from: data)
        else {
            assertionFailure("collections.json missing or malformed")
            return []
        }

        var byID: [String: Site] = [:]
        byID.reserveCapacity(SiteData.all.count)
        for site in SiteData.all { byID[site.id] = site }

        return raw.compactMap { collection in
            let held = collection.siteIDs.compactMap { byID[$0] }
            let sites = held.filter { !$0.isSensitive }
            // A set that lost most of itself to those filters is no longer the list it
            // claims to be, so it is dropped rather than shown short.
            guard sites.count >= 4 else { return nil }

            let lat = sites.reduce(0.0) { $0 + $1.latitude } / Double(sites.count)
            let lon = sites.reduce(0.0) { $0 + $1.longitude } / Double(sites.count)
            return ResolvedCollection(
                collection: collection,
                sites: sites,
                excludedAsSensitive: held.count - sites.count,
                centre: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
    }()

    /// What to actually put in front of someone.
    ///
    /// There are over a thousand collections and showing them all is the badge spam the
    /// research warns about, so the list is always either *yours* or *here*: anything you
    /// have started, then small places near you, then the World Heritage list for wherever
    /// you are. Everything else stays out of sight until it becomes relevant.
    static func surfaced(near origin: CLLocationCoordinate2D?,
                         visitedIDs: Set<String>) -> (inProgress: [ResolvedCollection],
                                                      nearby: [ResolvedCollection],
                                                      worldHeritage: [ResolvedCollection]) {
        let started = all.filter { $0.visitedCount(in: visitedIDs) > 0 }
            .sorted { a, b in
                let ra = Double(a.visitedCount(in: visitedIDs)) / Double(max(a.total, 1))
                let rb = Double(b.visitedCount(in: visitedIDs)) / Double(max(b.total, 1))
                return ra > rb
            }
        let startedIDs = Set(started.map(\.id))

        guard let origin else { return (started, [], []) }

        let nearby = all
            .filter { $0.collection.kind == .place && !startedIDs.contains($0.id) }
            .map { ($0, $0.sites[0].approxDistanceKm(from: origin)) }
            .filter { $0.1 < 60 }
            .sorted { $0.1 < $1.1 }
            .prefix(6)
            .map(\.0)

        let heritage = all
            .filter { $0.collection.kind == .worldHeritage && !startedIDs.contains($0.id) }
            .map { ($0, $0.sites[0].approxDistanceKm(from: origin)) }
            .sorted { $0.1 < $1.1 }
            .prefix(3)
            .map(\.0)

        return (started, Array(nearby), Array(heritage))
    }
}
