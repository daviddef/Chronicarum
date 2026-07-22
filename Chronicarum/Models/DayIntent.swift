import Foundation

/// How good a place has to be before it earns a place in your day.
///
/// The cut points are **measured, not chosen**: significance is already a 0–100 ranking
/// built from renown, designation grade and substance, so the bands are read off its real
/// distribution rather than picked to look tidy. Tier 1 is the top 0.2% of the catalogue —
/// small enough that every entry is somewhere you would cross a country for.
///
/// This is the "a 2,000-year-old castle beats a heritage house" dial. It does not need to
/// know about castles or houses: significance already scores the castle higher, and this
/// just decides where to cut.
enum SignificanceTier: Int, CaseIterable, Identifiable {
    case unmissable  = 1
    case worthATrip  = 2
    case worthALook  = 3
    case local       = 4

    var id: Int { rawValue }

    /// The floor a site must clear to belong to this tier or better.
    var minimumSignificance: Int {
        switch self {
        case .unmissable: 70
        case .worthATrip: 50
        case .worthALook: 33
        case .local:      0
        }
    }

    var label: String {
        switch self {
        case .unmissable: "Only the unmissable"
        case .worthATrip: "Worth the trip"
        case .worthALook: "Worth a look"
        case .local:      "Anything local"
        }
    }

    /// Roughly how much of the catalogue this opens up, so the choice is not abstract.
    var blurb: String {
        switch self {
        case .unmissable: "About 600 places worldwide — the ones you'd cross a country for."
        case .worthATrip: "About 5,000 — a proper day out, wherever you are."
        case .worthALook: "About 30,000 — includes the good local things."
        case .local:      "Everything, down to the listed milestone at the end of the lane."
        }
    }
}

/// What sort of day you have in mind.
///
/// The entry point to the app is a question — *what kind of day is this?* — rather than a
/// map you have to know how to filter. Each answer is a recipe: which themes, which kinds
/// of place, how good they have to be, and how you're getting around.
///
/// **Two of these are honest guesses and say so.** The catalogue records what a place *is*,
/// never whether it is fun with a seven-year-old or dry when it rains. Those two read
/// through `type` and `theme`, which is a reasonable proxy and not a fact, and the UI
/// labels them that way rather than implying a database of family attractions.
struct DayIntent: Identifiable, Hashable {
    let id: String
    let title: String
    let blurb: String
    let icon: String
    /// Themes to match. Empty means no theme preference.
    let themes: Theme
    /// Restrict to these kinds of place. Empty means any.
    let types: Set<SiteType>
    /// The default quality bar for this kind of day — overridable.
    let tier: SignificanceTier
    /// How you're most likely getting around for this sort of day.
    let mode: TravelMode
    /// Set where the *point* is the walking, so the plan can report progress toward it.
    let stepTarget: Int?
    /// Shown under the plan when the recipe is a proxy rather than recorded fact.
    let caveat: String?

    static let all: [DayIntent] = [
        DayIntent(
            id: "greatest",
            title: "The greatest hits",
            blurb: "Only the things you'd genuinely travel for.",
            icon: "crown",
            themes: [], types: [], tier: .unmissable, mode: .driving,
            stepTarget: nil, caveat: nil),

        DayIntent(
            id: "doorstep",
            title: "On my doorstep",
            blurb: "The history you walk past without noticing.",
            icon: "house",
            themes: [], types: [], tier: .local, mode: .walking,
            stepTarget: nil, caveat: nil),

        DayIntent(
            id: "history",
            title: "Deep history",
            blurb: "Romans, prehistory, ruins and castles.",
            icon: "building.columns",
            themes: [.roman, .prehistoric, .archaeology, .castles],
            types: [], tier: .worthALook, mode: .driving,
            stepTarget: nil, caveat: nil),

        DayIntent(
            id: "indoors",
            title: "It's raining",
            blurb: "Museums, churches and great houses — mostly under a roof.",
            icon: "cloud.rain",
            themes: [.museums, .grandHouses, .sacred],
            types: [.museum, .sacred, .heritage], tier: .worthALook, mode: .driving,
            stepTarget: nil,
            caveat: "The catalogue doesn't record whether a place is indoors. This picks "
                  + "the kinds of place that usually are — check before you set out in a "
                  + "downpour."),

        DayIntent(
            id: "kids",
            title: "With the kids",
            blurb: "Castles to climb, ruins to run around, things to look at.",
            icon: "figure.and.child.holdinghands",
            themes: [.castles, .museums, .gardens, .archaeology],
            types: [.castle, .museum, .ruin], tier: .worthALook, mode: .driving,
            stepTarget: nil,
            caveat: "Nothing in the catalogue says what's good with children. This is a "
                  + "guess from the kind of place it is — a castle usually beats a "
                  + "parish church on a wet Tuesday."),

        DayIntent(
            id: "steps",
            title: "Twenty thousand steps",
            blurb: "A long walk with something to see at every stop.",
            icon: "figure.walk.motion",
            themes: [], types: [], tier: .worthALook, mode: .walking,
            stepTarget: 20_000, caveat: nil),
    ]
}

extension DayIntent {
    /// Steps per kilometre walked, at an average stride of about 0.76 m. Used only to talk
    /// about a step goal in the units the goal is set in.
    static let stepsPerKm = 1_312.0
}
