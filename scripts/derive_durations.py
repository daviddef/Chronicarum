"""Estimate how long a visit to each site actually takes.

## Why

A day plan needs to know that Diocletian's Palace is a morning and a wayside cross is five
minutes. Nothing in any heritage register says so — registers record what a place *is*,
never how long you would stand in front of it. Without this, "seven days in Croatia" can
only be answered as a list, not a schedule.

## This is an estimate and is shipped as one

Durations come out in **bands** — 5, 10, 15, 20, 30, 45, 60, 90, 120, 180 minutes — never
as a computed figure like "37 minutes". The underlying signal is a theme and a few words in
a name; it does not support a number that precise, and printing one would imply a
confidence the data cannot carry. The app labels these "about 45 min" for the same reason.

## What the signal is

Measured first, which ruled out the obvious approach: **`tier` is 2 for all 260,008 bulk
sites**, so significance cannot drive this. What is left is themes, `type`, and scale words
in the name.

The base is the *longest* of a site's themes, not an average: a castle that also holds a
museum takes as long as the museum, not the mean of the two.
"""
import json, re, unicodedata
from collections import Counter

RESOURCES = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Resources"
BUNDLE = f"{RESOURCES}/bulk_sites.json"

# Must match derive_themes.py bit order.
THEME_NAMES = ["roman", "prehistoric", "castles", "sacred", "grand-houses", "military",
               "maritime", "industrial", "museums", "gardens", "archaeology", "civic",
               "rural", "monuments", "townscape", "grand-engineering"]

# Minutes a typical visitor spends, per theme. These are the least defensible numbers in
# the project and are meant to be argued with — they encode a view that most heritage is
# looked at from outside for a few minutes, and only a handful of categories are places you
# go *into* and stay.
THEME_MINUTES = {
    "museums": 90,          # you go in, you queue, you read things
    "townscape": 90,        # wandering a quarter, not visiting a building
    "grand-houses": 75,     # state rooms and usually grounds
    "castles": 60,
    "gardens": 60,
    "archaeology": 45,
    "roman": 45,
    "military": 40,
    "industrial": 30,
    "sacred": 25,           # a parish church; cathedrals are promoted below
    "prehistoric": 25,      # a barrow is a look and a walk back
    "civic": 20,
    "maritime": 20,
    "rural": 15,
    "grand-engineering": 15,
    "monuments": 10,        # a statue is a photograph
}

# No theme at all means an ordinary listed building — the 35% the theme model deliberately
# left untagged. You look at the front of it from the pavement.
UNTHEMED_MINUTES = 10

BANDS = [5, 10, 15, 20, 30, 45, 60, 90, 120, 180]


def fold(text):
    text = unicodedata.normalize("NFKD", text.lower())
    return "".join(c for c in text if not unicodedata.combining(c))


# Places you cannot see in the time their theme implies. A cathedral is not a parish
# church; a world heritage complex is not a building.
PROMOTIONS = [
    (re.compile(r"\b(?:historic complex|world heritage|historic district|conservation area"
                r"|old town|centre ancien|stari grad)\b"), 180),
    # "Palace" alone is not a signal of scale. It covers Diocletian's, a Madrid townhouse
    # and every Venetian merchant's house in Split — 685 rows, of which ~100 are royal.
    # A blanket promotion gave two hours to "Bajamonti-Dešković Palace" (a street facade)
    # and, absurdly, to "Buckingham Palace boundary walls". Grand-houses already provides
    # a sensible 90; only actual royal residences earn more.
    (re.compile(r"\b(?:royal palace|imperial palace|palace of the (?:king|emperor)"
                r"|winter palace|summer palace|papal palace|doge)\b"), 120),
    (re.compile(r"\bpalace\b.*\b(?:emperor|imperial|royal residence|world heritage)\b"
                r"|\b(?:emperor|imperial|royal)\b.*\bpalace\b"), 120),
    (re.compile(r"\b(?:cathedral|cathedrale|minster|basilica|basilique|katedrala|duomo"
                r"|abbey|abbaye|priory|monastery|monastere|samostan)\b"), 60),
    (re.compile(r"\b(?:national park|nature park|botanic|arboretum)\b"), 120),
    (re.compile(r"\b(?:amphitheatre|amphitheater|arena|forum|roman baths|thermae)\b"), 60),
]

# Things you glance at. These override everything, including a promotion — a market cross
# standing in a world heritage town centre is still a market cross.
GLANCE = re.compile(
    r"\b(?:milestone|milepost|mile post|boundary (?:stone|marker|post)|wayside cross"
    r"|market cross|gate ?pier|pillar ?box|post ?box|telephone (?:box|kiosk)|k6 kiosk"
    r"|horse trough|drinking fountain|water pump|lamp ?post|bollard|sundial|mounting block"
    r"|guide ?post|finger ?post|plaque|headstone|grave ?slab|croix|borne)\b")


# When a name BEGINS with one of these, that is what the site is, whatever else the name
# mentions. "Cross in the churchyard of the Church of St Nicholas" was getting a parish
# church's 30 minutes because the theme model quite correctly saw "churchyard" — but the
# site is the cross, and the cross is a two-minute look. The head noun settles it.
GLANCE_HEAD = re.compile(
    r"^(?:the\s+)?(?:cross|crosses|sundial|stocks|well|pump|milestone|boundary stone"
    r"|market cross|churchyard cross|preaching cross|high cross|celtic cross|stone cross"
    r"|monument|obelisk|statue|bust|fountain|horse trough|lamp|bollard|gate ?pier"
    r"|telephone|post ?box|pillar ?box|mounting block|tomb ?stone|headstone|memorial"
    r"|plaque|marker|signpost|guide ?post|finger ?post)\b")


# Components of a bigger site, recorded separately by registers that list every curtilage
# structure. A gatehouse, a boundary wall or a stable block is a thing you walk past on the
# way in, not a visit — and treating them as visits is how a day plan ends up claiming ten
# hours for one afternoon in Split.
COMPONENT_HEAD = re.compile(
    r"^(?:the\s+)?(?:gate ?house|gates?|gate ?piers?|railings?|walls?|boundary wall"
    r"|garden wall|terrace wall|forecourt|stable ?block|stables|outbuilding|coach ?house"
    r"|lodge|gazebo|summer ?house|ice ?house|dovecote|sundial|steps|balustrade"
    r"|entrance|screen|bridge over|part of|remains of|site of|wing of|range of)\b")


# Component phrases that are unambiguous wherever they appear, not only as a head noun.
# "Buckingham Palace boundary walls enclosing grounds" begins with "Buckingham", so the
# head-noun rule above let it keep the palace's duration — for a wall.
COMPONENT_ANY = re.compile(
    r"\b(?:boundary wall|garden wall|attached wall|forecourt wall|curtilage"
    r"|gate ?piers?|railings|area railings|retaining wall|perimeter wall"
    r"|walls? enclosing|attached railings)\b")

# A city gate is something you walk through on the way somewhere, however grand.
GATE_TAIL = re.compile(r"\b(?:gate|gateway|gates)$")


def minutes_for(site, themes):
    name = fold(site["name"])
    text = fold(site["name"] + " " + (site.get("desc") or ""))

    if GLANCE.search(text) or GLANCE_HEAD.search(name):
        return 5

    base = max((THEME_MINUTES[t] for t in themes), default=UNTHEMED_MINUTES)

    for pattern, promoted in PROMOTIONS:
        if pattern.search(text):
            base = max(base, promoted)

    # A component is capped AFTER promotions, so "Gatehouse, Holyrood Palace" cannot
    # inherit the palace's hour just by mentioning it.
    if COMPONENT_HEAD.search(name) or COMPONENT_ANY.search(text):
        base = min(base, 15)
    elif GATE_TAIL.search(name):
        base = min(base, 20)

    # Snap to the nearest band at or above the estimate, so the number shown is always a
    # round one a person would say out loud.
    for band in BANDS:
        if base <= band:
            return band
    return BANDS[-1]


def main():
    sites = json.load(open(BUNDLE))
    counts = Counter()

    for site in sites:
        mask = site.get("th", 0)
        themes = [THEME_NAMES[i] for i in range(len(THEME_NAMES)) if mask >> i & 1]
        minutes = minutes_for(site, themes)
        site["dur"] = minutes
        counts[minutes] += 1

    json.dump(sites, open(BUNDLE, "w"), ensure_ascii=False, separators=(",", ":"))

    total = len(sites)
    print(f"{total} sites\n")
    print("estimated visit duration:")
    for band in BANDS:
        n = counts[band]
        if n:
            bar = "█" * max(1, n * 40 // total)
            print(f"  {band:>4} min  {n:>7}  {n * 100 / total:5.1f}%  {bar}")
    total_minutes = sum(band * n for band, n in counts.items())
    print(f"\n  mean {total_minutes / total:.0f} min per site")


if __name__ == "__main__":
    main()
