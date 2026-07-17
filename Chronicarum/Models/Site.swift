import Foundation
import CoreLocation

// MARK: - Enumerations

enum Era: String, Codable, CaseIterable {
    case ancient     = "ancient"
    case classical   = "classical"
    case medieval    = "medieval"
    case renaissance = "renaissance"
    case modern      = "modern"

    var displayName: String {
        switch self {
        case .ancient:     return "Ancient"
        case .classical:   return "Classical"
        case .medieval:    return "Medieval"
        case .renaissance: return "Renaissance"
        case .modern:      return "Modern"
        }
    }

    var color: String {   // hex strings — swap for your design token
        switch self {
        case .ancient:     return "#C9A84C"
        case .classical:   return "#C05538"
        case .medieval:    return "#4A7FC1"
        case .renaissance: return "#4F8A5C"
        case .modern:      return "#6B7280"
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

    var displayName: String {
        switch self {
        case .wonder:      return "Wonder"
        case .castle:      return "Castle"
        case .sacred:      return "Sacred Site"
        case .battlefield: return "Battlefield"
        case .lostCity:    return "Lost City"
        case .treasure:    return "Treasure"
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
        }
    }

    var emoji: String {
        switch self {
        case .wonder:      return "🏛"
        case .castle:      return "🏰"
        case .sacred:      return "⛩️"
        case .battlefield: return "⚔️"
        case .lostCity:    return "🏚"
        case .treasure:    return "👑"
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

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isBookmarked: Bool = false
    var isVisited: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name, location, latitude, longitude, era, type, tier
        case builtDescription = "built"
        case civilisation = "civ"
        case tagline, chapters
        case nearestAirport, bestTimeToVisit, visaNote
    }
}

// MARK: - Cluster Model (for map grouping)

struct SiteCluster: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let sites: [Site]
    var count: Int { sites.count }
}
