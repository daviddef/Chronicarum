import Foundation
import CoreLocation

// MARK: - Enumerations

enum Era: String, Codable, CaseIterable {
    case ancient     = "ancient"
    case classical   = "classical"
    case medieval    = "medieval"
    case renaissance = "renaissance"
    case modern      = "modern"
    /// Formed by geology rather than people — Uluru, the Grand Canyon, the Twelve
    /// Apostles. Their human story is custodianship, not construction, so none of the
    /// historical eras fit.
    case geological  = "geological"
    /// Build date not known. Bulk-imported sites often have no inception date to bucket,
    /// and an honest "unknown" beats guessing an era from when a site was list-inscribed.
    case unknown     = "unknown"

    var displayName: String {
        switch self {
        case .ancient:     return "Ancient"
        case .classical:   return "Classical"
        case .medieval:    return "Medieval"
        case .renaissance: return "Renaissance"
        case .modern:      return "Modern"
        case .geological:  return "Geological"
        case .unknown:     return "Undated"
        }
    }

    var color: String {   // hex strings — swap for your design token
        switch self {
        case .ancient:     return "#C9A84C"
        case .classical:   return "#C05538"
        case .medieval:    return "#4A7FC1"
        case .renaissance: return "#4F8A5C"
        case .modern:      return "#6B7280"
        case .geological:  return "#8B6F47"
        case .unknown:     return "#9AA0A6"
        }
    }
}

enum SiteType: String, Codable, CaseIterable {
    case wonder      = "wonder"
    case castle      = "castle"
    case sacred      = "sacred"
    case battlefield = "battle"
    case lostCity    = "lost"
    case treasure    = "treasure"
    /// Landscape rather than building — Uluru, Victoria Falls, the Grand Canyon.
    case natural     = "natural"
    /// The institution itself, when it's the destination — the Louvre, the British Museum.
    case museum      = "museum"
    /// A specific object you travel to see, pinned at whatever houses it — the Mona Lisa,
    /// the Rosetta Stone. Distinct from `treasure`, which is a hoard rather than one work.
    case artefact    = "artefact"
    /// Built to be looked at rather than used — Christ the Redeemer, the moai, Rushmore.
    case monument    = "monument"
    /// Standing remains of a place still known and named, unlike `lostCity`, which was
    /// forgotten and rediscovered.
    case ruin        = "ruin"
    /// Generic bucket for bulk-imported sites of significance whose specific kind isn't
    /// known from the source data — most World Heritage sites arrive this way.
    case heritage    = "heritage"

    var displayName: String {
        switch self {
        case .wonder:      return "Wonder"
        case .castle:      return "Castle"
        case .sacred:      return "Sacred Site"
        case .battlefield: return "Battlefield"
        case .lostCity:    return "Lost City"
        case .treasure:    return "Treasure"
        case .natural:     return "Natural Wonder"
        case .museum:      return "Museum"
        case .artefact:    return "Artefact"
        case .monument:    return "Monument"
        case .ruin:        return "Ruin"
        case .heritage:    return "Heritage Site"
        }
    }

    var symbol: String {
        switch self {
        case .wonder:      return "pyramid"
        case .castle:      return "building.columns"
        case .sacred:      return "flame"
        case .battlefield: return "shield.lefthalf.filled"
        case .lostCity:    return "map"
        case .treasure:    return "crown"
        case .natural:     return "mountain.2"
        case .museum:      return "building.2"
        case .artefact:    return "photo.artframe"
        case .monument:    return "figure.stand"
        case .ruin:        return "building.columns.circle"
        case .heritage:    return "mappin.and.ellipse"
        }
    }

    var emoji: String {
        switch self {
        case .wonder:      return "🏛"
        case .castle:      return "🏰"
        // Neutral "place of worship" default — the catalogue's sacred sites span
        // many faiths, so no single tradition's symbol stands for all of them.
        // Individual sites override this via `Site.glyph`.
        case .sacred:      return "🛐"
        case .battlefield: return "⚔️"
        case .lostCity:    return "🏚"
        case .treasure:    return "👑"
        case .natural:     return "🏔"
        case .museum:      return "🖼"
        case .artefact:    return "🏺"
        case .monument:    return "🗿"
        case .ruin:        return "🧱"
        case .heritage:    return "📍"
        }
    }
}

// MARK: - Content Model

struct Fact: Codable, Identifiable {
    var id: String { label }
    let label: String
    let value: String
}

struct Chapter: Codable, Identifiable {
    let id: String
    let title: String
    let eyebrow: String
    let heading: String
    let body: String          // may contain HTML for rich rendering
    let facts: [Fact]
}

// MARK: - Core Site Model

struct Site: Codable, Identifiable {
    let id: String
    let name: String
    let location: String
    let latitude: Double
    let longitude: Double
    let era: Era
    let type: SiteType
    let tier: Int             // 1–5 significance rating
    let builtDescription: String
    let civilisation: String
    let tagline: String
    let chapters: [Chapter]

    // Travel layer
    let nearestAirport: String?
    let bestTimeToVisit: String?
    let visaNote: String?

    /// Optional per-site marker override. `type.emoji` is a fine default for most sites,
    /// but a single type can span traditions a category icon can't represent — a mosque,
    /// a church and a Shinto shrine are all `.sacred`. When set, this wins.
    var glyph: String? = nil

    /// Wikimedia Commons filename, e.g. `"Burg Eltz am frühen Morgen.jpg"`. Stored as the
    /// bare filename, not a URL, so thumbnail width stays a display decision.
    var imageFile: String? = nil

    /// Which dataset this site came from, when that dataset's licence requires saying so.
    /// `nil` for Wikidata (CC0) and the hand-authored sites, which owe no attribution.
    var dataSource: DataSource? = nil

    /// Theme bitmask — see `Theme`. Derived offline by `scripts/derive_themes.py`; stored
    /// raw rather than as `Theme` so the bundle stays a plain integer column.
    var themeMask: Int = 0

    /// Roughly how long a visit takes, in minutes. Derived offline by
    /// `scripts/derive_durations.py` and deliberately banded (5, 10, 15, 20, 30, 45, 60,
    /// 90, 120, 180) — the underlying signal is a theme and a few words in a name, which
    /// does not support a figure like "37 minutes". Zero means not estimated.
    var visitMinutes: Int = 0

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// The emoji actually drawn on the map: the site's own override, else its type's.
    var markerGlyph: String { glyph ?? type.emoji }

    /// Great-circle-ish distance in kilometres, via the equirectangular approximation.
    ///
    /// `CLLocation.distance(from:)` is exact but comparatively slow, and sorting 24k sites
    /// by proximity on every keystroke needs 24k of them. This is within a fraction of a
    /// percent at any distance the app shows and costs a few arithmetic ops. Exactness
    /// isn't the point when the label reads "412 km".
    func approxDistanceKm(from origin: CLLocationCoordinate2D) -> Double {
        let earthRadius = 6371.0
        let meanLat = ((latitude + origin.latitude) / 2) * .pi / 180
        let dLat = (latitude - origin.latitude) * .pi / 180
        let dLon = (longitude - origin.longitude) * .pi / 180 * cos(meanLat)
        return earthRadius * (dLat * dLat + dLon * dLon).squareRoot()
    }

    /// Commons thumbnail at the requested width. `Special:FilePath` redirects to the real
    /// file, so this stays valid even if the underlying storage path changes.
    func imageURL(width: Int = 800) -> URL? {
        guard let name = encodedImageName else { return nil }
        return URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/\(name)?width=\(width)")
    }

    /// The Commons file page, where the photo's licence and author are recorded. These
    /// images are free but not unconditional — anything displaying one should link here.
    var imageCreditURL: URL? {
        guard let name = encodedImageName else { return nil }
        return URL(string: "https://commons.wikimedia.org/wiki/File:\(name)")
    }

    private var encodedImageName: String? {
        guard let imageFile, !imageFile.isEmpty else { return nil }
        return imageFile.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
    }

    /// Places where treating a visit as something to *collect* would be offensive —
    /// death camps, massacre sites, slave forts, war graves, atomic bombing sites,
    /// political prisons.
    ///
    /// This exists because the catalogue is 24k sites bulk-imported from Wikidata, which
    /// certainly contains such places, and any future badge or collection layer would
    /// otherwise eventually award points for a genocide memorial. Pokémon GO did exactly
    /// this at Auschwitz-Birkenau and Hiroshima. Excluded from playful surfaces.
    ///
    /// Two mechanisms, because neither alone is sufficient. The keyword scan covers the
    /// bulk sites nobody can hand-review; the explicit list covers curated sites whose
    /// names give nothing away — Robben Island and Port Arthur read as a rock and a
    /// harbour. It deliberately over-flags: missing a death camp is unacceptable, while
    /// wrongly excluding a monument from a random-site button costs almost nothing.
    ///
    /// Only `name` and `tagline` are scanned, never the chapter body. Searching prose
    /// inverts meaning — the Pyramids entry says "Not slaves: organised labour gangs",
    /// which a body scan flagged as a slavery site.
    var isSensitive: Bool {
        if Self.explicitlySensitiveIDs.contains(id) { return true }
        let haystack = (name + " " + tagline).lowercased()
        return Self.sensitiveKeywords.contains { keyword in
            // Cheap substring test first: only ~2.5% of the catalogue matches at all, so
            // the costlier word-boundary check below is paid rarely.
            guard haystack.contains(keyword) else { return false }
            return Self.matchesAsWord(keyword, in: haystack)
        }
    }

    /// Substring matching alone flags "Pereyaslavets" — a medieval town — as a slavery
    /// site, the same way it once flagged the Pyramids. At 143k sites these coincidences
    /// stop being hypothetical, so a keyword has to start on a word boundary.
    ///
    /// Only the LEADING boundary is required, deliberately. Two tidier-looking versions
    /// were tried and both silently unflagged real sites: a trailing `\b` dropped "Izium
    /// mass graves" and every "burial grounds", and adding `(s|es)?` still dropped "Hỏa
    /// Lò Prison", whose description says "political prison**ers**". Guessing the set of
    /// suffixes is a losing game; letting the keyword run to the end of the word covers
    /// plurals, "slavery" and "prisoners" alike.
    ///
    /// The two errors here are not symmetric. Over-including costs an Independence
    /// Monument its place in the "surprise me" dice; under-including offers up a mass
    /// grave as a fun day out. So this leans, on purpose, toward over-including.
    private static func matchesAsWord(_ keyword: String, in haystack: String) -> Bool {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: keyword)
        return haystack.range(of: pattern, options: .regularExpression) != nil
    }

    private static let explicitlySensitiveIDs: Set<String> = [
        "robben-island",   // apartheid-era political prison
        "port-arthur",     // convict penal settlement; also a 1996 massacre site
    ]

    private static let sensitiveKeywords: [String] = [
        "holocaust", "auschwitz", "concentration camp", "extermination camp", "genocide",
        "shoah", "massacre", "atrocity", "killing field", "mass grave", "war crime",
        // "churchyard" belongs with "graveyard" and "cemetery": it is an active burial
        // ground with living relatives, not archaeology. Omitting it was an oversight
        // that left 1,176 of them eligible for playful surfaces.
        "cemetery", "burial ground", "graveyard", "churchyard", "necropolis", "ossuary",
        "war grave",
        "crematorium", "slave", "slavery", "atomic bomb", "hypocenter", "ground zero",
        "political prison", "gulag", "internment camp", "prison camp", "memorial", "victims",
        // Added with the US National Register, which surfaced whole categories the
        // earlier list never had to reach. 696 plantations were sitting unflagged —
        // "slave" does not appear in "Albania Plantation House", but a plantation is a
        // site of chattel slavery whatever the register calls it. "internment" is
        // broader than "internment camp" and catches the Japanese American sites;
        // "battlefield" covers war dead the way "war grave" already did.
        "plantation", "battlefield", "internment", "trail of tears", "lynching",
        "slave quarters",
    ]

    /// Whether this site's visa note carries a government travel warning.
    ///
    /// Read from the note's own wording rather than a hardcoded list of sites, so a
    /// newly added entry is covered the moment its advisory is written. A few sites in
    /// the catalogue (Bagan, Krak des Chevaliers, the Russia entries) are documented
    /// honestly but are not currently safe to visit — the app should say so plainly
    /// rather than bury it at the end of a paragraph.
    var hasTravelAdvisory: Bool {
        guard let note = visaNote?.lowercased() else { return false }
        return ["do not travel", "against all travel", "against all but essential",
                "level 4", "martial law", "state of emergency", "civil war"]
            .contains { note.contains($0) }
    }

    var isBookmarked: Bool = false
    var isVisited: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name, location, latitude, longitude, era, type, tier
        case builtDescription = "built"
        case civilisation = "civ"
        case tagline, chapters
        case nearestAirport, bestTimeToVisit, visaNote, glyph, imageFile, dataSource
        case themeMask, visitMinutes
    }
}

// MARK: - Data Sources

/// A bulk dataset whose licence obliges us to name it.
///
/// Wikidata is CC0 and owes nothing, which is why the first 34k sites carry no source of
/// their own. Government heritage registers are typically CC BY: free to use, including
/// commercially, provided the register is credited. That credit has to reach the user, so
/// it lives on the site itself rather than buried in a licences screen — the obligation
/// attaches to the record, and a reader looking at an SA place should see where it came
/// from without hunting for it.
enum DataSource: String, Codable, CaseIterable {
    case saHeritageRegister = "sahr"
    case merimee            = "merimee"
    case nrhp               = "nrhp"

    /// Shown under the description, e.g. "South Australian Heritage Places · CC BY 3.0 AU".
    var credit: String {
        switch self {
        case .saHeritageRegister: "South Australian Heritage Places · CC BY 3.0 AU"
        case .merimee:            "Base Mérimée, Ministère de la Culture · Licence Ouverte 2.0"
        // Public domain under 17 U.S.C. §105, so this credit is owed to nobody. It is
        // here because the register did the work and the line costs nothing.
        case .nrhp:               "National Register of Historic Places · National Park Service"
        }
    }

    /// Where the licence and the original record live.
    var url: URL? {
        switch self {
        case .saHeritageRegister:
            URL(string: "https://data.sa.gov.au/data/dataset/sa-heritage-places")
        case .merimee:
            URL(string: "https://data.culture.gouv.fr/explore/dataset/liste-des-immeubles-proteges-au-titre-des-monuments-historiques/")
        case .nrhp:
            URL(string: "https://www.nps.gov/subjects/nationalregister/index.htm")
        }
    }
}

// MARK: - Cluster Model (for map grouping)

/// One map annotation: either a single site (`count == 1`) or a group merged because
/// they fell in the same grid cell at the current zoom.
struct SiteCluster: Identifiable {
    /// Derived from the grid cell, not a UUID — a fresh UUID each recompute would give
    /// SwiftUI a new identity every frame and break annotation reuse and animation.
    let id: String
    let coordinate: CLLocationCoordinate2D
    let sites: [Site]

    var count: Int { sites.count }
    var isSingle: Bool { sites.count == 1 }

    /// Roughly how spread out the group is: the distance across its bounding box.
    /// Cheaper and more intuitive than a true diameter — it answers "is this a
    /// walkable cluster or a whole region?".
    var spanKm: Double {
        guard let minLat = sites.map(\.latitude).min(),
              let maxLat = sites.map(\.latitude).max(),
              let minLon = sites.map(\.longitude).min(),
              let maxLon = sites.map(\.longitude).max() else { return 0 }
        let earthRadius = 6371.0
        let meanLat = ((minLat + maxLat) / 2) * .pi / 180
        let dLat = (maxLat - minLat) * .pi / 180
        let dLon = (maxLon - minLon) * .pi / 180 * cos(meanLat)
        return earthRadius * (dLat * dLat + dLon * dLon).squareRoot()
    }

    /// An order to walk the group in, nearest-neighbour from `origin` (the user, when
    /// known, else the northern-most site).
    ///
    /// Nearest-neighbour is a greedy heuristic, not an optimal tour — solving that
    /// properly is the travelling salesman problem. For a handful of sites in one
    /// neighbourhood it produces a sensible order, and it's honest to call it a
    /// suggestion rather than the shortest possible route.
    func route(from origin: CLLocationCoordinate2D?) -> (stops: [Site], totalKm: Double) {
        guard !sites.isEmpty else { return ([], 0) }
        var remaining = sites
        var ordered: [Site] = []
        var total = 0.0

        var cursor: CLLocationCoordinate2D
        if let origin {
            cursor = origin
        } else {
            let start = remaining.max { $0.latitude < $1.latitude }!
            cursor = start.coordinate
            remaining.removeAll { $0.id == start.id }
            ordered.append(start)
        }

        while !remaining.isEmpty {
            let cursorPoint = cursor
            guard let idx = remaining.indices.min(by: {
                remaining[$0].approxDistanceKm(from: cursorPoint)
                    < remaining[$1].approxDistanceKm(from: cursorPoint)
            }) else { break }
            let next = remaining.remove(at: idx)
            total += next.approxDistanceKm(from: cursorPoint)
            ordered.append(next)
            cursor = next.coordinate
        }
        return (ordered, total)
    }

    /// The site that represents the group — highest tier wins, so a cluster takes the
    /// colour and (when single) the marker of its most significant member.
    var representative: Site {
        sites.max { $0.tier < $1.tier } ?? sites[0]
    }
}
