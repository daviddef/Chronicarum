import Foundation

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
