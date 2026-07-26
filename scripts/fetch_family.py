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

# Metro bounding boxes (south, west, north, east). Family POIs are dense — a whole-country
# query times out — so coverage is city-by-city where the people are. Overlaps are fine,
# deduplicated by id. Add a box to widen.
REGIONS = {
    # Australia
    "seq":       (-28.30, 152.60, -26.90, 153.60),  # Brisbane + Gold Coast + Sunshine edge
    "sydney":    (-34.20, 150.45, -33.50, 151.40),
    # Melbourne split in two — the whole-metro box is dense enough to 504 both endpoints.
    "melbourne_w": (-38.25, 144.30, -37.50, 144.95),
    "melbourne_e": (-38.25, 144.95, -37.50, 145.60),
    "perth":     (-32.60, 115.55, -31.55, 116.25),
    "adelaide":  (-35.40, 138.30, -34.60, 138.95),
    "canberra":  (-35.55, 148.90, -35.05, 149.30),
    "hobart":    (-43.10, 147.05, -42.65, 147.60),
    "darwin":    (-12.55, 130.80, -12.30, 131.10),
    # UK & Ireland. Central London is so dense it 504s even quartered, so the two northern
    # quadrants are split again into east/west eighths; the southern halves came back whole.
    "london_nww": (51.48, -0.52, 51.70, -0.32),
    "london_nwe": (51.48, -0.32, 51.70, -0.11),
    "london_new": (51.48, -0.11, 51.70, 0.10),
    "london_nee": (51.48, 0.10, 51.70, 0.30),
    "london_sw": (51.28, -0.52, 51.48, -0.11),
    "london_se": (51.28, -0.11, 51.48, 0.30),
    "manchester":(53.34, -2.42, 53.56, -2.10),
    "birmingham":(52.38, -2.05, 52.58, -1.75),
    "leeds":     (53.72, -1.68, 53.88, -1.42),
    "liverpool": (53.34, -3.05, 53.48, -2.85),
    "glasgow":   (55.78, -4.40, 55.93, -4.10),
    "edinburgh": (55.88, -3.36, 56.00, -3.04),
    "bristol":   (51.40, -2.74, 51.52, -2.48),
    "cardiff":   (51.44, -3.26, 51.55, -3.08),
    "dublin":    (53.28, -6.44, 53.44, -6.04),
    # Continental Europe — the heritage catalogue's strongest markets. Paris and Berlin split.
    "paris_w":   (48.80, 2.18, 48.91, 2.35),
    "paris_e":   (48.80, 2.35, 48.91, 2.52),
    "rome":      (41.80, 12.40, 41.99, 12.60),
    "barcelona": (41.34, 2.09, 41.47, 2.24),
    "madrid":    (40.35, -3.79, 40.51, -3.62),
    "berlin_w":  (52.45, 13.18, 52.58, 13.41),
    "berlin_e":  (52.45, 13.41, 52.58, 13.62),
    "amsterdam": (52.31, 4.81, 52.43, 4.99),
    "vienna":    (48.16, 16.30, 48.29, 16.46),
    "munich":    (48.08, 11.47, 48.21, 11.66),
    "milan":     (45.40, 9.10, 45.53, 9.26),
    "lisbon":    (38.69, -9.23, 38.80, -9.08),
    # United States — dense metros split. Queued for a quieter Overpass window.
    "nyc_man":   (40.70, -74.02, 40.82, -73.91),
    "nyc_bkln":  (40.57, -74.04, 40.74, -73.85),
    "la_w":      (33.95, -118.55, 34.10, -118.35),
    "la_e":      (33.95, -118.35, 34.15, -118.15),
    "chicago":   (41.80, -87.75, 41.98, -87.58),
    "sf":        (37.70, -122.52, 37.82, -122.38),
    "boston":    (42.29, -71.15, 42.41, -71.02),
    "washdc":    (38.82, -77.12, 38.99, -76.91),
    "seattle":   (47.50, -122.44, 47.73, -122.24),
}

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


def query(bbox):
    keys = {}
    for (k, v) in CATEGORIES:
        keys.setdefault(k, []).append(v)
    s, w, n, e = bbox
    parts = []
    for k, vs in keys.items():
        parts.append(f'nwr["{k}"~"^({"|".join(vs)})$"]({s},{w},{n},{e});')
    return f"[out:json][timeout:180];\n(\n  " + "\n  ".join(parts) + "\n);\nout center tags;"


def fetch_region(name, bbox):
    cache = os.path.join(SCRIPTS, f".family_cache_{name}.json")
    if os.path.exists(cache):
        print(f"  {name}: cached", file=sys.stderr)
        return json.load(open(cache)).get("elements", [])
    data = urllib.parse.urlencode({"data": query(bbox)}).encode()
    for ep in OVERPASS_ENDPOINTS:
        try:
            print(f"  {name}: querying {ep.split('/')[2]}…", file=sys.stderr)
            req = urllib.request.Request(ep, data=data,
                                         headers={"User-Agent": "Chronicarum/family (ODbL import)"})
            with urllib.request.urlopen(req, timeout=240) as resp:
                raw = json.load(resp)
            json.dump(raw, open(cache, "w"))
            print(f"  {name}: {len(raw.get('elements', []))} features", file=sys.stderr)
            return raw.get("elements", [])
        except Exception as exc:
            print(f"  {name}: {ep.split('/')[2]} failed ({exc})", file=sys.stderr)
            time.sleep(5)
    return []


def fetch():
    by_id = {}
    for name, bbox in REGIONS.items():
        for el in fetch_region(name, bbox):
            by_id[f"{el['type'][0]}{el['id']}"] = el   # dedup across overlapping boxes
        time.sleep(2)
    print(f"  merged: {len(by_id)} unique features across {len(REGIONS)} regions", file=sys.stderr)
    return list(by_id.values())


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

    # First pass: named parks, indexed into a ~1 km grid so naming a playground checks only
    # the parks in its own cell and the eight around it — O(n), not parks × playgrounds, which
    # at national scale would be hundreds of millions of comparisons.
    park_grid = {}
    for el in elements:
        t = el.get("tags", {})
        if t.get("leisure") == "park" and t.get("name"):
            la, lo = coord(el)
            if la is not None:
                park_grid.setdefault((round(la, 2), round(lo, 2)), []).append((la, lo, t["name"]))

    def nearest_park_name(la, lo):
        best, name = PLAYGROUND_NAME_RADIUS_KM, None
        cla, clo = round(la, 2), round(lo, 2)
        for dla in (-0.01, 0, 0.01):
            for dlo in (-0.01, 0, 0.01):
                for pla, plo, pn in park_grid.get((round(cla + dla, 2), round(clo + dlo, 2)), []):
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
    rows = dedupe_near(rows)
    columns = {k: [r[k] for r in rows]
               for k in ("id", "name", "lat", "lon", "type", "sig", "dur", "th", "desc")}
    with open(OUT, "w") as f:
        json.dump(columns, f, ensure_ascii=False, separators=(",", ":"))

    from collections import Counter
    by = Counter(r["type"] for r in rows)
    size = os.path.getsize(OUT) / 1024
    print(f"wrote {len(rows)} family places -> {OUT} ({size:.0f} KB)", file=sys.stderr)
    print("  " + ", ".join(f"{k}:{v}" for k, v in by.most_common()), file=sys.stderr)


def dedupe_near(rows):
    """Drop near-duplicates: the same place mapped twice — "Biami Yumba" and "Biami Yumba
    Park" a few metres apart. Rows arrive sorted by score, so the first (best) survives and
    a later one with the same base name within 200 m is dropped. Grid-indexed to stay O(n)."""
    def base(n):
        n = n.lower().strip()
        for suf in (" park", " playground", " reserve", " gardens", " oval", " parkland"):
            if n.endswith(suf):
                n = n[: -len(suf)].strip()
        return n
    kept, grid = [], {}
    for r in rows:
        bn, la, lo = base(r["name"]), r["lat"], r["lon"]
        cla, clo = round(la, 2), round(lo, 2)
        dup = False
        for dla in (-0.01, 0, 0.01):
            for dlo in (-0.01, 0, 0.01):
                for (kla, klo, kbn) in grid.get((round(cla + dla, 2), round(clo + dlo, 2)), []):
                    if kbn == bn and haversine_km((la, lo), (kla, klo)) < 0.2:
                        dup = True
                        break
                if dup:
                    break
            if dup:
                break
        if not dup:
            kept.append(r)
            grid.setdefault((cla, clo), []).append((la, lo, bn))
    return kept


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
