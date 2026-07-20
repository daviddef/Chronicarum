import Foundation
import CoreLocation

/// What a site is *about*, as a traveller would say it.
///
/// `Era` and `SiteType` describe a site the way a catalogue does — a period name and a
/// building category. Neither can express the sentence this whole feature exists to
/// answer: *"I like castles and Roman history."* Themes are that vocabulary.
///
/// They are deliberately **not a partition**. A Norman castle with a chapel inside is
/// `.castles` *and* `.sacred`; a Roman aqueduct is `.roman` *and* `.grandEngineering`.
/// A site carries as many as apply, which is what lets a preference be answered as a
/// union rather than forcing a person to pick one box.
///
/// Derived offline by `scripts/derive_themes.py` and shipped as a bitmask per site, so
/// matching is an integer AND rather than a string search over 260k rows. **The raw
/// values are bit positions and must never be reordered** — the catalogue is labelled
/// against them, so inserting a case in the middle would silently re-label everything.
/// Append only, and re-run the script when you do.
struct Theme: OptionSet, Hashable {
    let rawValue: Int

    static let roman            = Theme(rawValue: 1 << 0)
    static let prehistoric      = Theme(rawValue: 1 << 1)
    static let castles          = Theme(rawValue: 1 << 2)
    static let sacred           = Theme(rawValue: 1 << 3)
    static let grandHouses      = Theme(rawValue: 1 << 4)
    static let military         = Theme(rawValue: 1 << 5)
    static let maritime         = Theme(rawValue: 1 << 6)
    static let industrial       = Theme(rawValue: 1 << 7)
    static let museums          = Theme(rawValue: 1 << 8)
    static let gardens          = Theme(rawValue: 1 << 9)
    static let archaeology      = Theme(rawValue: 1 << 10)
    static let civic            = Theme(rawValue: 1 << 11)
    static let rural            = Theme(rawValue: 1 << 12)
    static let monuments        = Theme(rawValue: 1 << 13)
    static let townscape        = Theme(rawValue: 1 << 14)
    static let grandEngineering = Theme(rawValue: 1 << 15)

    /// Presentation order — roughly "what people ask for most" rather than bit order.
    static let all: [Theme] = [
        .castles, .roman, .sacred, .prehistoric, .grandHouses, .archaeology, .military,
        .maritime, .industrial, .museums, .gardens, .monuments, .townscape, .civic,
        .rural, .grandEngineering,
    ]

    var label: String {
        switch self {
        case .roman:            "Roman & classical"
        case .prehistoric:      "Prehistoric"
        case .castles:          "Castles & forts"
        case .sacred:           "Churches & abbeys"
        case .grandHouses:      "Grand houses"
        case .military:         "Military & wartime"
        case .maritime:         "Coast & maritime"
        case .industrial:       "Industrial"
        case .museums:          "Museums & galleries"
        case .gardens:          "Gardens & parks"
        case .archaeology:      "Archaeology"
        case .civic:            "Civic & public life"
        case .rural:            "Farms & countryside"
        case .monuments:        "Monuments & memorials"
        case .townscape:        "Old towns & streets"
        case .grandEngineering: "Bridges & engineering"
        default:                "Other"
        }
    }

    var glyph: String {
        switch self {
        case .roman:            "🏛"
        case .prehistoric:      "🗿"
        case .castles:          "🏰"
        case .sacred:           "⛪️"
        case .grandHouses:      "🏛"
        case .military:         "⚔️"
        case .maritime:         "⚓️"
        case .industrial:       "⚙️"
        case .museums:          "🖼"
        case .gardens:          "🌳"
        case .archaeology:      "🏺"
        case .civic:            "🏛"
        case .rural:            "🌾"
        case .monuments:        "🗽"
        case .townscape:        "🏘"
        case .grandEngineering: "🌉"
        default:                "📍"
        }
    }

    /// The individual themes set on this value, in presentation order.
    var components: [Theme] {
        Theme.all.filter { contains($0) }
    }
}

extension Site {
    /// Themes carried by this site. Empty for the ~35% of the catalogue that is ordinary
    /// buildings — a listed terraced house is not "about" anything in this sense, and
    /// inventing a theme for it would make every theme mean less.
    var themes: Theme { Theme(rawValue: themeMask) }

    /// True when the site matches any of the wanted themes. An empty selection means "no
    /// preference expressed", which matches everything rather than nothing — a filter the
    /// user has not touched should never hide the catalogue.
    func matches(themes wanted: Theme) -> Bool {
        wanted.isEmpty || !themes.intersection(wanted).isEmpty
    }
}

extension Site {
    /// "about 45 min" — phrased as an estimate because it is one. Never renders a precise
    /// figure: the bands exist so the app cannot imply a confidence the data lacks.
    var visitDurationLabel: String? {
        guard visitMinutes > 0 else { return nil }
        if visitMinutes < 60 { return "about \(visitMinutes) min" }
        let hours = Double(visitMinutes) / 60
        return hours == hours.rounded()
            ? "about \(Int(hours)) hr"
            : "about \(String(format: "%.1f", hours)) hr"
    }
}

extension Collection where Element == Site {
    /// Total visiting time for a set of sites, excluding travel between them.
    var totalVisitMinutes: Int { reduce(0) { $0 + $1.visitMinutes } }
}

// MARK: - Containment

extension Collection where Element == Site {
    /// Visiting time with contained sites folded into their container.
    ///
    /// Registers describe the same place at several scales. Within 400 m of Split's centre
    /// the catalogue holds the UNESCO complex, Diocletian's Palace inside it, and the gates
    /// inside that — all correct, all separate records. Summing them claims ten hours for
    /// one afternoon.
    ///
    /// So a site whose parent is *also in this collection* contributes nothing: you are
    /// already spending the container's time, and the parts are what you see while you are
    /// there. A site whose parent is elsewhere still counts in full — visiting one gate of
    /// a city wall on the far side of town is a real, separate stop.
    var visitMinutesFoldingContained: Int {
        let present = Set(map(\.id))
        return reduce(0) { total, site in
            if let parent = site.parentID, present.contains(parent) { return total }
            return total + site.visitMinutes
        }
    }

    /// Sites that are contained by something else in this collection — the ones folded
    /// away above, worth listing as "you'll see these while you're there".
    var containedWithin: [Site] {
        let present = Set(map(\.id))
        return filter { site in
            guard let parent = site.parentID else { return false }
            return present.contains(parent)
        }
    }
}

// MARK: - Worth a detour

extension Site {
    /// Significance discounted by how far away it is — "what is worth my time from here".
    ///
    /// Raw significance answers a different question. Sorting 260k sites by it while
    /// standing in Split offers Gorée in Senegal, 4,593 km away: correct as a global
    /// ranking and useless as an answer to "where should I go today". Distance alone is
    /// no better — it offers the six listed townhouses on this street while the cathedral
    /// sits 300 m further on.
    ///
    /// The half-life is 25 km: a site 25 km away needs twice the significance of one at
    /// your feet to rank alongside it, which is roughly how people actually trade off a
    /// detour against a better destination.
    func detourScore(from origin: CLLocationCoordinate2D) -> Double {
        Double(significance) / (1 + approxDistanceKm(from: origin) / 25)
    }
}
