"""Derive travel themes for every site in the catalogue.

## Why

The app can filter by `era` (seven European period names) and `type` (seven categories).
Neither can express what a person actually says: *"I like castles and Roman history."*
That sentence is the product, and nothing in stages 4-6 of the roadmap — preferences, day
plans, itineraries — can start until a site can say what it is *about*.

## Why rules and not a model

260,008 rows. Hand-labelling is impossible and LLM-labelling at that scale is expensive,
non-reproducible and — worse — unverifiable: a wrong label would be indistinguishable from
a right one without reading all 260k. Keyword rules are inspectable, deterministic, free to
re-run when the catalogue grows, and wrong in ways that can be *found* by sampling. When
the rules are wrong, the fix is a visible one-line change rather than a re-run of something
opaque.

## What the signal actually is

Measured before writing any rules, which changed the design:

    era known                   30%   <- cannot anchor "Roman" on era
    type == "heritage"          60%   <- the generic bucket; type is weak
    description present         51%   <- absent for 106k UK sites entirely
    name present               100%   <- the only universal signal

So the rules run mostly over **names**, and names are multilingual: English (UK, US,
Australia), French (Mérimée), Croatian, and whatever language Wikidata holds a global site
under. Each theme therefore carries its own vocabulary in every language the catalogue
actually contains, rather than an English list plus hope.

Themes are **not a partition**. A Norman castle keeping a chapel is `castles` and `sacred`
and `medieval-life`; a site carries as many as apply, which is what makes "castles and
Roman history" answerable as a union.
"""
import json, re, sys, unicodedata
from collections import Counter

RESOURCES = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Resources"
BUNDLE = f"{RESOURCES}/bulk_sites.json"

# ── Theme vocabulary ──────────────────────────────────────────────────────────────────
# Order defines the bit position and must stay stable: the app decodes a bitmask, so
# inserting a theme in the middle would silently re-label the whole catalogue. Append only.
THEMES = [
    ("roman", [
        # English / general
        r"\broman\b", r"\bromano-", r"\bvilla rustica\b", r"\bamphitheatre\b", r"\bamphitheater\b",
        r"\bhypocaust\b", r"\bcastrum\b", r"\bmansio\b", r"\baqueduct\b", r"\bmosaic pavement\b",
        r"\blegionary\b", r"\bmilecastle\b", r"\bvallum\b", r"\bforum\b", r"\bthermae\b",
        # French (Mérimée)
        r"\bgallo-romain", r"\bromaine?\b", r"\baqueduc\b", r"\bthermes\b", r"\bamphithe",
        r"\bvoie romaine\b", r"\bvestiges gallo",
        # Croatian / Italian / Latin-derived
        r"\brimsk", r"\bantick", r"\banfiteatro\b", r"\bterme\b",
        # Named Roman places and people that carry no generic keyword at all. Without
        # these, Diocletian's Palace, Verulamium and Hadrian's Wall — the three sites a
        # person asking for "Roman history" would name first — were tagged as anything
        # but Roman.
        r"\bdiocletian", r"\bverulamium\b", r"\bhadrian", r"\bvindolanda\b",
        r"\bcaerleon\b", r"\bantonine\b", r"\bcaerwent\b", r"\bfishbourne\b",
        r"\bvilla romaine\b", r"\bcastellum\b", r"\bdecumanus\b", r"\bcardo\b",
        r"\bimperial (?:palace|forum)\b", r"\btepidarium\b", r"\bcaldarium\b",
    ]),
    ("prehistoric", [
        r"\bbarrow\b", r"\bbarrows\b", r"\bcairn\b", r"\btumulus\b", r"\btumuli\b",
        r"\bstone circle\b", r"\bstanding stone", r"\bmenhir\b", r"\bdolmen\b", r"\bcromlech\b",
        r"\bhenge\b", r"\bhillfort\b", r"\bhill fort\b", r"\bbroch\b", r"\bcrannog\b",
        r"\bsouterrain\b", r"\bmegalith", r"\bchambered\b", r"\bcist\b", r"\bpetroglyph",
        r"\brock art\b", r"\bcup and ring\b", r"\bneolithic\b", r"\bbronze age\b",
        r"\biron age\b", r"\bpalaeolithic\b", r"\bmesolithic\b", r"\bmound\b", r"\bearthwork",
        r"\bprehistor", r"\bpréhistor", r"\bnéolithique\b", r"\bâge du bronze\b",
        r"\boppidum\b", r"\bgradina\b", r"\bpretpovijesn",
    ]),
    ("castles", [
        r"\bcastle\b", r"\bcastles\b", r"\bfortress\b", r"\bfortification", r"\bcitadel\b",
        r"\bkeep\b", r"\bbastion\b", r"\brampart", r"\bcity wall", r"\btown wall",
        r"\bmotte\b", r"\bbailey\b", r"\btower house\b", r"\bpeel tower\b", r"\bbroch\b",
        r"\bmartello\b", r"\bblockhouse\b", r"\bgatehouse\b", r"\bmoat\b", r"\bdrawbridge\b",
        r"\bchâteau\b", r"\bchateau\b", r"\bforteresse\b", r"\bdonjon\b", r"\bremparts?\b",
        r"\benceinte\b", r"\btour de défense\b", r"\bcitadelle\b",
        r"\bkaštel\b", r"\bkastel\b", r"\butvrda\b", r"\bgrad\b", r"\bburg\b", r"\bschloss\b",
    ]),
    ("sacred", [
        r"\bchurch\b", r"\bchapel\b", r"\bcathedral\b", r"\bminster\b", r"\bbasilica\b",
        r"\babbey\b", r"\bpriory\b", r"\bmonaster", r"\bconvent\b", r"\bfriary\b",
        r"\bnunnery\b", r"\bhermitage\b", r"\bmosque\b", r"\bsynagogue\b", r"\btemple\b",
        r"\bshrine\b", r"\bmeeting ?house\b", r"\bmanse\b", r"\brectory\b", r"\bvicarage\b",
        r"\bpresbytery\b", r"\bcloister\b", r"\bbell tower\b", r"\bcampanile\b",
        r"\béglise\b", r"\beglise\b", r"\bchapelle\b", r"\bcathédrale\b", r"\babbaye\b",
        r"\bprieuré\b", r"\bcouvent\b", r"\bmonastère\b", r"\bbasilique\b", r"\bcalvaire\b",
        r"\bcrkva\b", r"\bcrkve\b", r"\bkapela\b", r"\bsamostan\b", r"\bkatedrala\b",
        r"\bkirche\b", r"\bchiesa\b", r"\biglesia\b",
    ]),
    ("grand-houses", [
        r"\bpalace\b", r"\bmanor\b", r"\bmansion\b", r"\bhall\b", r"\bcountry house\b",
        r"\bstately home\b", r"\bestate\b", r"\bvilla\b", r"\bchateau\b", r"\bmanoir\b",
        r"\bhôtel particulier\b", r"\bpalais\b", r"\bdemeure\b", r"\bdvorac\b", r"\bpalača\b",
        r"\bpalazzo\b", r"\borangery\b", r"\bdower house\b",
    ]),
    ("military", [
        r"\bbattlefield\b", r"\bbattle of\b", r"\bfort\b", r"\bforts\b", r"\bbarracks\b",
        r"\barmoury\b", r"\barmory\b", r"\barsenal\b", r"\bmagazine\b", r"\bredoubt\b",
        r"\bbattery\b", r"\bpillbox\b", r"\bbunker\b", r"\bairfield\b", r"\bair base\b",
        r"\bnaval base\b", r"\bwar memorial\b", r"\bgarrison\b", r"\bdrill hall\b",
        r"\bregiment", r"\bmilitary\b", r"\bmilitaire\b", r"\bcaserne\b", r"\bpoudrière\b",
        r"\bvojarna\b", r"\bmaginot\b", r"\bblockhaus\b",
    ]),
    ("maritime", [
        r"\blighthouse\b", r"\blight station\b", r"\bharbour\b", r"\bharbor\b", r"\bpier\b",
        r"\bjetty\b", r"\bwharf\b", r"\bquay\b", r"\bdock\b", r"\bdockyard\b", r"\bboathouse\b",
        r"\bshipwreck\b", r"\bshipyard\b", r"\blifeboat\b", r"\bcustoms house\b",
        r"\bnavigation\b", r"\bnaval\b", r"\bmarine\b", r"\bport\b",
        r"\bphare\b", r"\bquai\b", r"\bchantier naval\b", r"\bsvjetionik\b", r"\bluka\b",
    ]),
    ("industrial", [
        r"\bmill\b", r"\bmills\b", r"\bwatermill\b", r"\bwindmill\b", r"\bfactory\b",
        r"\bworks\b", r"\bfoundry\b", r"\bforge\b", r"\bsmithy\b", r"\bkiln\b", r"\bcolliery\b",
        r"\bmine\b", r"\bmining\b", r"\bquarry\b", r"\bbrewery\b", r"\bdistillery\b",
        r"\bwarehouse\b", r"\bgasworks\b", r"\bwaterworks\b", r"\bpumping station\b",
        r"\brailway\b", r"\brailroad\b", r"\bviaduct\b", r"\bengine house\b", r"\btannery\b",
        r"\bmoulin\b", r"\busine\b", r"\bmanufacture\b", r"\bforges\b", r"\bmine\b",
        r"\bbrasserie\b", r"\bmlin\b", r"\btvornica\b",
    ]),
    ("museums", [
        r"\bmuseum\b", r"\bgallery\b", r"\bart gallery\b", r"\bmusée\b", r"\bmusee\b",
        r"\bgalerie\b", r"\bmuzej\b", r"\bpinacoteca\b", r"\bkunsthalle\b",
    ]),
    ("gardens", [
        r"\bgarden\b", r"\bgardens\b", r"\bpark\b", r"\bparkland\b", r"\barboretum\b",
        r"\bbotanic", r"\bpleasure ground\b", r"\bavenue of\b", r"\bjardin\b", r"\bparc\b",
        r"\bperivoj\b", r"\bvrt\b", r"\borangerie\b",
    ]),
    ("archaeology", [
        r"\barchaeolog", r"\barcheolog", r"\bexcavation\b", r"\bruins?\b", r"\bremains of\b",
        r"\bsite of\b", r"\bdeserted\b", r"\bsettlement site\b", r"\bnécropole\b",
        r"\bnecropolis\b", r"\bcatacomb", r"\bvestiges\b", r"\bnalazište\b", r"\bruševine\b",
    ]),
    ("civic", [
        r"\btown hall\b", r"\bcity hall\b", r"\bcourthouse\b", r"\bcourt house\b",
        r"\bguildhall\b", r"\bpost office\b", r"\blibrary\b", r"\bschool\b", r"\bcollege\b",
        r"\bacademy\b", r"\buniversity\b", r"\bhospital\b", r"\binfirmary\b", r"\bmarket hall\b",
        r"\bexchange\b", r"\bcustom house\b", r"\bfire station\b", r"\bpolice station\b",
        r"\bbank\b", r"\bmairie\b", r"\bhôtel de ville\b", r"\bhotel de ville\b", r"\bécole\b",
        r"\bbibliothèque\b", r"\blycée\b", r"\bopća\b", r"\bškola\b",
        r"\btheatre\b", r"\btheater\b", r"\bopera house\b", r"\bcinema\b",
        r"\bassembly rooms\b", r"\bthéâtre\b", r"\bkazalište\b",
    ]),
    ("rural", [
        r"\bfarm\b", r"\bfarmhouse\b", r"\bbarn\b", r"\bgranary\b", r"\bdovecote\b",
        r"\bstables?\b", r"\bcottage\b", r"\bcroft\b", r"\bhomestead\b", r"\bwoolshed\b",
        r"\bshearing shed\b", r"\bthreshing\b", r"\bferme\b", r"\bgrange\b", r"\bpigeonnier\b",
        r"\bcolombier\b", r"\blavoir\b", r"\bpuits\b", r"\bseoska\b",
    ]),
    # Appended after the first full pass. 7,637 sites typed `monument` carried no theme at
    # all — the vocabulary had bridges and aqueducts but nothing for the statue, obelisk or
    # war memorial a person actually walks past.
    ("monuments", [
        r"\bmonument\b", r"\bmemorial\b", r"\bstatue\b", r"\bobelisk\b", r"\bcenotaph\b",
        r"\bmausoleum\b", r"\btomb\b", r"\bfountain\b", r"\bmarket cross\b",
        r"\bwayside cross\b", r"\bmilestone\b", r"\bmilepost\b", r"\bplaque\b",
        r"\bcolumn\b", r"\btriumphal arch\b", r"\bstele\b",
        r"\bfontaine\b", r"\bcroix\b", r"\bcalvaire\b", r"\bstèle\b", r"\bmonumento\b",
        r"\bspomenik\b", r"\bfontana\b",
    ]),
    # Whole streets and quarters rather than single buildings — "wandering an old town" is
    # a real reason to travel and nothing else in the vocabulary expressed it.
    ("townscape", [
        r"\bhistoric district\b", r"\bconservation area\b", r"\bold town\b",
        r"\btown centre\b", r"\bhistoric centre\b", r"\bhistoric center\b",
        r"\bterrace\b", r"\bcrescent\b", r"\bhigh street\b", r"\bmarket place\b",
        r"\bmarket square\b", r"\bcentre ancien\b", r"\bsecteur sauvegarde\b",
        r"\bcjelina\b", r"\bstari grad\b", r"\burbana\b",
    ]),
    ("grand-engineering", [
        r"\bbridge\b", r"\baqueduct\b", r"\bviaduct\b", r"\btunnel\b", r"\bdam\b",
        r"\breservoir\b", r"\bobservatory\b", r"\bpont\b", r"\bbarrage\b", r"\bmost\b",
        r"\bcanal\b", r"\block\b", r"\bwharf\b",
    ]),
]

# Patterns that VETO a theme even when an include pattern matched. Added after measuring
# the first pass, which produced three false positives large enough to poison the feature:
# 410 "Roman Catholic" churches tagged as Roman history, 590 town halls tagged as grand
# houses, and architectural "gate piers" tagged as maritime. Each is a word that means one
# thing in heritage vocabulary and something else entirely in ordinary English.
VETOES = {
    "roman": [r"\broman\s+catholic", r"\bromain\s+catholique", r"\brimokatolick"],
    "grand-houses": [
        r"\b(?:town|city|village|market|guild|music|parish|church|memorial|masonic"
        r"|concert|dance|meeting|dining|banqueting|assembly|drill|temperance)\s*hall\b",
    ],
    "maritime": [r"\bgate\s+pier"],
    # "Dover Castle Hotel" is a pub. British and Australian pubs are overwhelmingly named
    # after castles, ships and coats of arms, and a castle-themed itinerary that routes
    # someone to a Wetherspoons is worse than one that misses a real castle.
    "castles": [r"\b(?:hotel|inn|public house|\bpub\b|tavern|arms|hostel|motel)\b"],
    # "11324 Pearlstone Lane" is an address, not a quarter. `\bterrace\b` and friends were
    # tagging 2,826 individual street addresses as townscape, which then inherited the
    # 90-minute "wander an old town" duration — 4,100 hours of imaginary sightseeing.
    # A leading house number means a single building, unless the name says otherwise:
    # "2900 Block Grove Avenue Historic District" really is a district.
    "townscape": [r"^\d+[a-z]?\s+(?!.*\b(?:district|conservation|quarter|centre|center"
                  r"|old town|historic area)\b)"],
}

THEME_NAMES = [name for name, _ in THEMES]
# One alternation per theme rather than one regex per pattern. With ~250 patterns over
# 260k sites the naive form is 65M separate searches and takes minutes per run, which
# makes tuning the vocabulary impractical; this is ~14 searches per site instead.
COMPILED = [(name, re.compile("|".join(pats)),
             re.compile("|".join(VETOES[name])) if name in VETOES else None)
            for name, pats in THEMES]

# Type and era give a weak second signal. Only applied where the site has NO theme from
# text at all — otherwise a generic type would drown out a specific name match.
TYPE_FALLBACK = {
    "sacred": "sacred", "castle": "castles", "museum": "museums",
    "ruin": "archaeology", "natural": "gardens", "monument": "monuments",
}
ERA_THEME = {"classical": "roman", "ancient": "prehistoric"}


def fold(text):
    """Lowercase and strip accents so "château" matches "chateau" and Croatian
    diacritics do not have to be doubled up in every pattern."""
    text = unicodedata.normalize("NFKD", text.lower())
    return "".join(c for c in text if not unicodedata.combining(c))


def themes_for(site):
    haystack = fold(site["name"] + " " + (site.get("desc") or ""))
    found = set()
    for name, pattern, veto in COMPILED:
        if pattern.search(haystack) and not (veto and veto.search(haystack)):
            found.add(name)

    # Era is a weak signal but an unambiguous one where it exists, so it ADDS rather than
    # only filling gaps: a classically-dated site is Roman-adjacent whatever its name says,
    # and that is exactly the case a "Roman history" preference must not miss.
    era_theme = ERA_THEME.get(site.get("era"))
    if era_theme:
        found.add(era_theme)

    # Type only fills a genuine gap — it is too coarse to add alongside a name match.
    if not found:
        fallback = TYPE_FALLBACK.get(site.get("type"))
        if fallback:
            found.add(fallback)
    return found


def bitmask(names):
    mask = 0
    for i, theme in enumerate(THEME_NAMES):
        if theme in names:
            mask |= 1 << i
    return mask


def main():
    sites = json.load(open(BUNDLE))
    counts, untagged, multi = Counter(), 0, Counter()

    for site in sites:
        found = themes_for(site)
        site["th"] = bitmask(found)
        if not found:
            untagged += 1
        for theme in found:
            counts[theme] += 1
        multi[len(found)] += 1

    json.dump(sites, open(BUNDLE, "w"), ensure_ascii=False, separators=(",", ":"))

    total = len(sites)
    print(f"{total} sites, {total - untagged} tagged ({(total - untagged) * 100 // total}%), "
          f"{untagged} with no theme")
    print("\nper theme:")
    for theme in THEME_NAMES:
        n = counts[theme]
        print(f"  {theme:<20} {n:>7}  {n * 100 / total:5.1f}%")
    print("\nthemes per site:", dict(sorted(multi.items())))


if __name__ == "__main__":
    main()
