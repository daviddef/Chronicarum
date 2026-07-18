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

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// The emoji actually drawn on the map: the site's own override, else its type's.
    var markerGlyph: String { glyph ?? type.emoji }

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
        case nearestAirport, bestTimeToVisit, visaNote, glyph, imageFile
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

    /// The site that represents the group — highest tier wins, so a cluster takes the
    /// colour and (when single) the marker of its most significant member.
    var representative: Site {
        sites.max { $0.tier < $1.tier } ?? sites[0]
    }
}
