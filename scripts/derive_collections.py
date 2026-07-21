"""Build the bounded collections the app scores progress against.

## Why bounded, and why so few

The retention research in ROADMAP.md is unusually clear about what fails. Foursquare
stripped its own gamification and said why: points were arbitrary across heterogeneous
places, and hundreds of badges meant badges "stopped feeling special". Open-ended scoring
over 294,820 sites would be exactly that. What works instead is a **finite set where 100%
means something** — the US National Park Passport, ~433 units, which exists explicitly to
push visitors toward smaller places they would otherwise skip.

So collections here are official lists, not inventions, and there are few of them.

## The two families

**World Heritage of <country>.** Canonical, externally defined, and — the part that makes
it work as a passport rather than a trophy cabinet — genuinely long-tailed. Everyone has
been to Bath; almost nobody has been to Blaenavon, Saltaire or the Flow Country, and they
are on the same list of 31.

**Everything in <small place>.** The complete designated record of somewhere small enough
to finish. This is where the roadside chapel lives — the long tail that no popularity
ranking will ever surface. These are only ever shown when you are near one or have started
one, which is what stops 1,000 of them being the badge spam Foursquare warned about.

## Two things that needed care

**Serial inscriptions.** UNESCO gives Hadrian's Wall an inscription number and *also* gives
one to every milefortlet along it. Counting those as separate World Heritage Sites put the
UK at 235 against a real 35. Only bare-numbered ids (`430`, not `430-001`) are whole
inscriptions; suffixed ones are components. Wikidata also occasionally holds two items for
one inscription — "Durham Castle" and "Durham Castle and Cathedral" both carry 404 — so
membership is deduplicated by inscription number, keeping the most significant item.

**Sensitive sites are *not* filtered here.** `Site.isSensitive` is a Swift computed
property covering death camps, massacre sites, plantations and burial grounds, and it is
the guard that keeps them out of playful surfaces. Porting it to Python would create a
second copy that could silently drift, and the cost of drift here is a collection that
invites someone to tick off a genocide memorial. The app filters membership on load
instead, so there stays exactly one implementation and the totals shown always agree with
it.
"""
import json, math, re, unicodedata
from collections import Counter, defaultdict

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
ROOT = "/Users/daviddefranceski/Claude/Projects/Chronicarum"
BUNDLE = f"{ROOT}/Chronicarum/Resources/bulk_sites.json"
OUT = f"{ROOT}/Chronicarum/Resources/collections.json"

# A country needs enough inscriptions for the set to feel like a list rather than a
# footnote, and every collection needs to be finishable.
MIN_WHS = 5
LOCALITY_MIN, LOCALITY_MAX = 6, 30
# A place whose record is a dozen untitled "Immeuble" entries is a chore, not a collection.
MIN_SUBSTANTIAL = 4
MAX_LOCALITY_COLLECTIONS = 1200
# Single-linkage distance, and the gap that has to surround a cluster for "all" to be true.
LINK_KM, ISOLATION_KM = 0.5, 0.8
LINK_CELL = 0.01          # ~1.1 km, so a 3x3 cell sweep covers both radii


def km(a, b):
    scale = math.cos(math.radians(a["lat"]))
    return math.hypot((a["lat"] - b["lat"]) * 111, (a["lon"] - b["lon"]) * 111 * scale)


def slug(text):
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def substantial(site):
    """Something a visitor would recognise as worth a stop: a picture, some prose, or a
    significance high enough to have earned it elsewhere."""
    return bool(site.get("img")) or bool(site.get("desc")) or site.get("sig", 0) >= 30


def main():
    sites = json.load(open(BUNDLE))
    by_id = {s["id"]: s for s in sites}
    whs_rows = json.load(open(f"{SP}/whs_p757.json"))["results"]["bindings"]

    # ── World Heritage ────────────────────────────────────────────────────
    # Bare number = the inscription itself; anything suffixed is a component of it.
    inscription_of = {}
    for b in whs_rows:
        qid = b["item"]["value"].rsplit("/", 1)[-1]
        number = b["id"]["value"]
        if re.fullmatch(r"\d+", number):
            inscription_of["wd-" + qid] = number

    # One item per inscription — the most significant, where Wikidata holds several.
    best_for = {}
    for site_id, number in inscription_of.items():
        site = by_id.get(site_id)
        if site is None:
            continue
        current = best_for.get(number)
        if current is None or site.get("sig", 0) > by_id[current].get("sig", 0):
            best_for[number] = site_id

    by_country = defaultdict(list)
    for number, site_id in best_for.items():
        country = by_id[site_id]["country"].split(", ")[-1]
        by_country[country].append(site_id)

    # How many inscriptions each country actually has, which is not the same as how many
    # the catalogue holds — the UK has 36 and we hold 31. A collection titled "World
    # Heritage Sites of the United Kingdom" showing 31 would be quietly claiming that is
    # the whole list, so the real total is carried through and the app says what is missing.
    total_rows = json.load(open(f"{SP}/whs_totals.json"))["results"]["bindings"]
    inscriptions_per_country = defaultdict(set)
    for b in total_rows:
        if re.fullmatch(r"\d+", b["id"]["value"]):
            inscriptions_per_country[b["countryLabel"]["value"]].add(b["id"]["value"])

    # Wikidata's country label and the catalogue's differ in places; only the ones that
    # match can carry an honest denominator, and a country with no denominator is dropped
    # rather than shown with an unstated one.
    collections = []
    dropped_no_total = 0
    for country, members in sorted(by_country.items()):
        if len(members) < MIN_WHS:
            continue
        total = len(inscriptions_per_country.get(country, ()))
        if total < len(members):
            dropped_no_total += 1
            continue
        members.sort(key=lambda i: -by_id[i].get("sig", 0))
        collections.append({
            "id": f"whs-{slug(country)}",
            "kind": "worldHeritage",
            "title": f"World Heritage Sites of {country}",
            "blurb": "UNESCO's own list. The famous ones and the ones nobody expects.",
            "region": country,
            "unescoTotal": total,
            "sites": members,
        })

    whs_count = len(collections)

    # ── Everywhere small enough to finish ─────────────────────────────────
    localities = defaultdict(list)
    for s in sites:
        localities[s["country"]].append(s["id"])

    # A locality *label* is not a boundary, and treating it as one produced false claims.
    # The first run offered "Every designated place in London — 24 of them"; London has
    # thousands, and only 24 rows carry the bare label because the rest are tagged by
    # borough. Bungay claimed 6 with 11 standing on the ground. A collection that says
    # "all" has to mean it.
    #
    # So the boundary is geometric, and completeness holds by construction: single-linkage
    # clustering at 500 m, then the cluster is only kept if nothing else stands within
    # 800 m of any member. Whatever that leaves genuinely is everything there.
    cluster_of = {}
    clusters = defaultdict(list)
    grid = defaultdict(list)
    for s in sites:
        grid[(int(s["lat"] / LINK_CELL), int(s["lon"] / LINK_CELL))].append(s)

    def neighbours(site, radius_km):
        cy, cx = int(site["lat"] / LINK_CELL), int(site["lon"] / LINK_CELL)
        out = []
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                for other in grid[(cy + dy, cx + dx)]:
                    if other["id"] != site["id"] and km(site, other) <= radius_km:
                        out.append(other)
        return out

    # Union-find over the 500 m linkage.
    parent = {s["id"]: s["id"] for s in sites}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for s in sites:
        for other in neighbours(s, LINK_KM):
            a, b = find(s["id"]), find(other["id"])
            if a != b:
                parent[a] = b

    for s in sites:
        clusters[find(s["id"])].append(s["id"])

    local = []
    for members in clusters.values():
        if not (LOCALITY_MIN <= len(members) <= LOCALITY_MAX):
            continue
        if sum(substantial(by_id[i]) for i in members) < MIN_SUBSTANTIAL:
            continue
        member_set = set(members)
        # The isolation gap. Without it a "complete" village set sits 550 m from a site it
        # silently omits.
        if any(other["id"] not in member_set
               for i in members for other in neighbours(by_id[i], ISOLATION_KM)):
            continue

        labels = Counter(by_id[i]["country"] for i in members)
        locality = labels.most_common(1)[0][0]
        parts = locality.split(", ")
        place, country = parts[0], parts[-1]
        if place == country:
            continue                     # no locality was recorded at all
        # Unresolved Wikidata identifiers leaked through as place names: "All of Q634054".
        if re.fullmatch(r"Q\d+", place):
            continue
        members.sort(key=lambda i: -by_id[i].get("sig", 0))
        score = sum(by_id[i].get("sig", 0) for i in members) / len(members)
        local.append((score, {
            "id": f"place-{slug(locality)}",
            "kind": "place",
            "title": f"All of {place}",
            # No count in the blurb. The app removes sensitive members after this runs, so a
            # number baked in here contradicted the list beside it — "6 of them" above
            # "0 of 4 visited". The resolved count is the only honest one.
            "blurb": f"Every designated place around {place}.",
            "region": locality,
            "sites": members,
        }))

    local.sort(key=lambda pair: -pair[0])
    collections.extend(entry for _, entry in local[:MAX_LOCALITY_COLLECTIONS])

    json.dump(collections, open(OUT, "w"), ensure_ascii=False,
              separators=(",", ":"))

    total_members = sum(len(c["sites"]) for c in collections)
    print(f"{len(collections):,} collections -> {OUT}")
    print(f"  world heritage : {whs_count:,} countries "
          f"({dropped_no_total} dropped for want of a matching UNESCO total)")
    print(f"  places         : {len(collections) - whs_count:,} "
          f"(of {len(local):,} eligible)")
    print(f"  total memberships: {total_members:,}")

    print("\n  largest World Heritage sets:")
    for c in sorted(collections[:whs_count], key=lambda c: -len(c["sites"]))[:6]:
        print(f"    {c['title'][:46]:<48} {len(c['sites']):>3} of {c['unescoTotal']}")
    print("\n  sample place sets:")
    for c in collections[whs_count:whs_count + 6]:
        print(f"    {c['title'][:34]:<36} {len(c['sites']):>3}  {c['region'][:34]}")


if __name__ == "__main__":
    main()
