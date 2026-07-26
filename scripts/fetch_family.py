"""Extract kid-friendly places — playgrounds, parks, beaches, zoos, water parks — from
OpenStreetMap, so "With the kids" can offer what a child actually wants rather than only
scheduled monuments.

The gap this fills: the heritage catalogue has castles and museums and nothing a four-year-old
would cross the road for. See ROADMAP.md "'With the kids' — the things kids actually want".

Source and licence: OpenStreetMap `leisure`/`tourism`/`natural` POIs, ODbL — the same
collective-database footing as the trails. Ships in its OWN bundled file (`family.json`),
attributed to OSM, kept separate from the Wikidata heritage layer. These become `Site`s at
load with the new family `SiteType`s and a `family` theme, so the ordinary planner picks them
up and a day can string a castle *and* a playground *and* the beach.

The curation is per-category, because the raw layer is a mix of destinations and private
noise: 3,500 "swimming pools" in Brisbane are backyards, 1,000 "gardens" are front lawns. So
some tags are kept wholesale (a playground is a destination by its very type), some only when
named, and the two noisy ones are dropped.

Pilot region: South East Queensland (Brisbane to the Gold Coast). Stdlib only.
"""
import json, os, math, time, urllib.request, urllib.parse, sys

RESOURCES = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Chronicarum/Resources")
OUT = f"{RESOURCES}/family.json"
SCRIPTS = os.path.dirname(os.path.abspath(__file__))

OVERPASS_ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]

# South East Queensland: Brisbane, Moreton Bay, the Gold Coast. (south, west, north, east)
BBOX = (-28.30, 152.60, -26.90, 153.60)

# Each category: (osm_key, osm_value) -> (SiteType, base significance, visit minutes, keep-rule).
# keep-rule "all" = a destination by type; "named" = only if it carries a name.
CATEGORIES = {
    ("tourism", "theme_park"):    ("themepark", 66, 240, "all"),
    ("tourism", "zoo"):           ("wildlife",  60, 150, "all"),
    ("tourism", "aquarium"):      ("wildlife",  60, 120, "all"),
    ("leisure", "water_park"):    ("waterplay", 55, 150, "all"),
    ("natural", "beach"):         ("beach",     50, 120, "named"),
    ("leisure", "nature_reserve"):("park",      48,  90, "named"),
    ("leisure", "playground"):    ("playground",46,  45, "all"),
    ("leisure", "park"):          ("park",      42,  60, "named"),
    ("tourism", "picnic_site"):   ("park",      38,  45, "named"),
}
# Scores are deliberately compressed into a narrow band, not spread 30–90: a nearby
# playground has to be able to out-score a koala park an hour's drive away, once the
# planner's distance penalty applies, or a kids' day becomes two far-flung big-ticket
# attractions and no local swings. The hero destinations still lead, just not by so much.

# Theme bits (must match Theme in Swift). family is new; the outdoor bits let "A day
# outdoors" pick these up too.
THEME_FAMILY   = 1 << 16
THEME_GARDENS  = 1 << 9
THEME_MARITIME = 1 << 6

PLAYGROUND_NAME_RADIUS_KM = 0.4   # name an unnamed playground from a park this close


def query():
    keys = {}
    for (k, v) in CATEGORIES:
        keys.setdefault(k, []).append(v)
    s, w, n, e = BBOX
    parts = []
    for k, vs in keys.items():
        parts.append(f'nwr["{k}"~"^({"|".join(vs)})$"]({s},{w},{n},{e});')
    return f"[out:json][timeout:180];\n(\n  " + "\n  ".join(parts) + "\n);\nout center tags;"


def fetch():
    cache = os.path.join(SCRIPTS, ".family_cache.json")
    if os.path.exists(cache):
        print("using cached response (delete scripts/.family_cache.json to refresh)", file=sys.stderr)
        return json.load(open(cache)).get("elements", [])
    data = urllib.parse.urlencode({"data": query()}).encode()
    for attempt, ep in enumerate(OVERPASS_ENDPOINTS):
        try:
            print(f"querying {ep.split('/')[2]}…", file=sys.stderr)
            req = urllib.request.Request(ep, data=data,
                                         headers={"User-Agent": "Chronicarum/family (ODbL import)"})
            with urllib.request.urlopen(req, timeout=240) as resp:
                raw = json.load(resp)
            json.dump(raw, open(cache, "w"))
            return raw.get("elements", [])
        except Exception as exc:
            print(f"  {ep.split('/')[2]} failed ({exc})", file=sys.stderr)
            time.sleep(5)
    return []


def haversine_km(a, b):
    R = 6371.0
    lat1, lon1, lat2, lon2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    dlat, dlon = lat2 - lat1, lon2 - lon1
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return 2 * R * math.asin(math.sqrt(h))


def coord(el):
    if el.get("type") == "node":
        return (el.get("lat"), el.get("lon"))
    c = el.get("center")
    return (c["lat"], c["lon"]) if c else (None, None)


def score(base, tags, sitetype):
    """Family richness → 0–90, the kids' analogue of significance. A place earns points for
    being a named, equipped, toddler-safe destination rather than a bare patch of grass."""
    s = base
    if tags.get("name"):                                  s += 10
    for k in ("toilets", "drinking_water", "bbq"):
        if tags.get(k) in ("yes", "1"):                   s += 3
    if tags.get("shade") in ("yes", "partial"):           s += 3
    if sitetype == "playground" and tags.get("fenced") == "yes":  s += 6   # safe for littlies
    if sitetype == "park" and tags.get("playground") == "yes":    s += 8   # a park with a playground
    return min(90, s)


def theme_mask(sitetype):
    m = THEME_FAMILY
    if sitetype in ("park", "playground"):  m |= THEME_GARDENS
    if sitetype == "beach":                 m |= THEME_MARITIME
    return m


def build():
    elements = fetch()
    print(f"  {len(elements)} raw features", file=sys.stderr)

    # First pass: named parks, for naming the many unnamed playgrounds by the park they sit in.
    named_parks = []
    for el in elements:
        t = el.get("tags", {})
        if t.get("leisure") == "park" and t.get("name"):
            la, lo = coord(el)
            if la is not None:
                named_parks.append((la, lo, t["name"]))

    def nearest_park_name(la, lo):
        best, name = PLAYGROUND_NAME_RADIUS_KM, None
        for pla, plo, pn in named_parks:
            d = haversine_km((la, lo), (pla, plo))
            if d < best:
                best, name = d, pn
        return name

    seen = set()
    rows = []
    for el in elements:
        t = el.get("tags", {})
        # Which category is this? (a feature can carry several keys; take the first match.)
        matched = None
        for (k, v), spec in CATEGORIES.items():
            if t.get(k) == v:
                matched = spec
                break
        if matched is None:
            continue
        sitetype, base, dur, rule = matched
        la, lo = coord(el)
        if la is None:
            continue

        name = (t.get("name") or "").strip()
        if not name:
            if sitetype == "playground":
                park = nearest_park_name(la, lo)
                name = f"{park} playground" if park else "Playground"
            elif rule == "named":
                continue    # a nameless park/beach is noise; drop it
            else:
                name = sitetype.capitalize()

        key = f"{el['type'][0]}{el['id']}"
        if key in seen:
            continue
        seen.add(key)

        rows.append({
            "id": f"family/{key}",
            "name": name,
            "lat": round(la, 6),
            "lon": round(lo, 6),
            "type": sitetype,
            "sig": score(base, t, sitetype),
            "dur": dur,
            "th": theme_mask(sitetype),
            "desc": describe(sitetype, t),
        })

    rows.sort(key=lambda r: -r["sig"])
    columns = {k: [r[k] for r in rows]
               for k in ("id", "name", "lat", "lon", "type", "sig", "dur", "th", "desc")}
    with open(OUT, "w") as f:
        json.dump(columns, f, ensure_ascii=False, separators=(",", ":"))

    from collections import Counter
    by = Counter(r["type"] for r in rows)
    size = os.path.getsize(OUT) / 1024
    print(f"wrote {len(rows)} family places -> {OUT} ({size:.0f} KB)", file=sys.stderr)
    print("  " + ", ".join(f"{k}:{v}" for k, v in by.most_common()), file=sys.stderr)


def describe(sitetype, tags):
    label = {"themepark": "Theme park", "wildlife": "Wildlife", "waterplay": "Water play",
             "beach": "Beach", "park": "Park", "playground": "Playground"}.get(sitetype, "Place")
    extras = []
    if tags.get("toilets") in ("yes", "1"):        extras.append("toilets")
    if tags.get("drinking_water") in ("yes", "1"): extras.append("water")
    if tags.get("bbq") in ("yes", "1"):            extras.append("BBQ")
    if tags.get("fenced") == "yes":                extras.append("fenced")
    return label + (" · " + ", ".join(extras) if extras else "")


if __name__ == "__main__":
    build()
