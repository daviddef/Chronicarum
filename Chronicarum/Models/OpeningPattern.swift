import Foundation

/// What is *typically* true about when a kind of place is open.
///
/// ## This is guidance, never a claim about a specific site
///
/// There is no usable source for opening hours, and that was measured rather than assumed:
/// Wikidata's `P3025` covers **703 designated sites worldwide** (0.27%); OpenStreetMap
/// carries `opening_hours` on **5%** of heritage objects in both Bath and Split, and would
/// cost the ODbL obligation to publish our derived database in exchange. No heritage
/// register records hours at all — registers describe what a place *is*.
///
/// So the app never says "open 9–5". It says what is *commonly* true of cathedrals or of
/// museums, always hedged, always paired with a way to check. The distinction matters:
/// a wrong opening time sends someone across a city to a locked door, and a plan that
/// quietly invents them is worse than one that admits it does not know.
///
/// The patterns themselves are ordinary travel knowledge — museums often shut on Mondays,
/// outdoor ruins rarely shut at all — applied by theme.
struct OpeningPattern {
    /// Weekdays this kind of place is commonly closed. `Calendar` weekday numbering:
    /// 1 = Sunday … 7 = Saturday.
    let commonlyClosedWeekdays: Set<Int>
    /// Whether opening tends to be seasonal, with short or no winter hours.
    let isSeasonal: Bool
    /// Shown to the reader, hedged.
    let note: String

    static let alwaysOpen = OpeningPattern(
        commonlyClosedWeekdays: [], isSeasonal: false,
        note: "Usually open ground you can walk up to at any time.")

    /// Looked up by theme, most specific first — a site that is both a museum and a castle
    /// takes the museum's pattern, because the ticket desk is what closes.
    static func forSite(_ site: Site) -> OpeningPattern? {
        let themes = site.themes

        if themes.contains(.museums) {
            return OpeningPattern(
                commonlyClosedWeekdays: [2], isSeasonal: false,
                note: "Museums are commonly closed on Mondays.")
        }
        if themes.contains(.grandHouses) {
            return OpeningPattern(
                commonlyClosedWeekdays: [2], isSeasonal: true,
                note: "Historic houses often close on Mondays and over winter.")
        }
        if themes.contains(.castles) {
            return OpeningPattern(
                commonlyClosedWeekdays: [], isSeasonal: true,
                note: "Castles that charge admission often keep shorter winter hours; "
                    + "ruined ones are usually open ground.")
        }
        if themes.contains(.gardens) {
            return OpeningPattern(
                commonlyClosedWeekdays: [], isSeasonal: true,
                note: "Gardens usually keep daylight hours and vary by season.")
        }
        if themes.contains(.sacred) {
            return OpeningPattern(
                commonlyClosedWeekdays: [], isSeasonal: false,
                note: "Churches are usually open in the day, but may close for services.")
        }
        if !themes.intersection([.prehistoric, .archaeology, .monuments,
                                 .townscape, .grandEngineering]).isEmpty {
            return .alwaysOpen
        }
        return nil
    }

    func isCommonlyClosed(on date: Date, calendar: Calendar = .current) -> Bool {
        commonlyClosedWeekdays.contains(calendar.component(.weekday, from: date))
    }
}

extension Site {
    var openingPattern: OpeningPattern? { OpeningPattern.forSite(self) }
}
