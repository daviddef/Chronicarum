"""Extract named national/international walking and cycling routes from OpenStreetMap.

The outdoor layer. Everything else in the catalogue is a *point* — a place you stand in
front of. A trail is a *line* you travel along for its own sake, so it is its own record,
not a bent `Site`. See ROADMAP.md "The outdoors — trails, walks, bike rides".

Source and licence: OpenStreetMap route relations, ODbL. The extracted geometry shipped in
the app is a Derivative Database, so it must be attributed to OSM and offered under ODbL on
request — which is why it lives in its OWN bundled file (`trails.json`), a collective
database kept separate from the heritage catalogue rather than merged into it. The Overpass
query below IS the "means of creating" we offer on request.

Deliberately: **national and international named routes only** (`network` in iwn/nwn for
walking, icn/ncn for cycling). Local footpaths run to millions and would drown the signal
exactly as the unfiltered heritage import did; the network tier is the significance filter
all over again.

Coverage is Europe, the contiguous United States, and Australia/New Zealand — queried as
separate regional bounding boxes (a single planet-wide Overpass query would time out) and
merged. Overlapping boxes are deduplicated by relation id; a route spanning two boxes is
reassembled by the name-merge in `build()`.

Output is columnar, mirroring `build_columnar.py`, and small enough to bundle without LFS:
each trail's geometry is simplified (Ramer-Douglas-Peucker) and stored as a precision-5
encoded polyline.

Stdlib only — no third-party deps, same as the other fetch scripts.
"""
import json, os, math, re, time, urllib.request, urllib.parse, sys

RESOURCES = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Chronicarum/Resources")
OUT = f"{RESOURCES}/trails.json"
SCRIPTS = os.path.dirname(os.path.abspath(__file__))

# A couple of endpoints; if the first is busy (429) or times out, fall back to the second.
OVERPASS_ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]

# Regional bounding boxes: (south, west, north, east). Overlaps are fine — dedup by id.
# The US prefers public-domain USGS/NPS data in principle (see ROADMAP); until that pipeline
# exists, OSM under ODbL covers it, and the attribution already rides on every trail.
REGIONS = {
    "britain_ireland": (49.8, -11.0, 61.1, 2.1),
    "iberia":          (35.5, -10.0, 44.6, 4.6),
    "france":          (41.0, -5.5, 51.6, 8.4),
    "central_europe":  (45.5, 5.8, 55.6, 19.6),   # DE, CH, AT, CZ, PL, SI
    "italy_adriatic":  (36.0, 6.0, 46.6, 20.2),   # Italy, Croatia, W Balkans
    "nordic":          (54.5, 4.0, 71.5, 31.6),
    "se_europe":       (34.5, 19.0, 48.6, 30.2),  # Greece, E Balkans, Romania, Bulgaria
    "usa":             (24.0, -125.0, 49.5, -66.5),
    "australia_nz":    (-48.0, 112.0, -9.5, 179.5),
}

# route -> our activity bucket. Walking and cycling only; horse/ski/canoe routes are real
# OSM route types but not what "out for a walk / on two wheels" asks for.
ACTIVITY = {"hiking": "walk", "foot": "walk", "bicycle": "bike", "mtb": "bike"}
# The tiers we keep, per activity — national and international only.
KEEP_NETWORK = {"iwn", "nwn", "icn", "ncn"}

MIN_KM, MAX_KM = 2.0, 5000.0
RDP_EPSILON_DEG = 0.0006   # ~65 m; enough to hold the shape of a long path cheaply.
MAX_POINTS = 90            # cap per trail so one monster relation can't bloat the bundle.
CLUSTER_GAP_KM = 60.0      # stages of one route are near each other; a bigger jump is a
                           # different route that happens to share a (generic) name.


def overpass_query(bbox):
    routes = "|".join(sorted(ACTIVITY))
    nets = "|".join(sorted(KEEP_NETWORK))
    s, w, n, e = bbox
    return f"""
[out:json][timeout:300];
(
  relation["route"~"^({routes})$"]["network"~"^({nets})$"]["name"]({s},{w},{n},{e});
);
out geom;
"""


def fetch_region(name, bbox):
    """One region, cached to scripts/.trails_cache_<name>.json. Delete to refresh."""
    cache = os.path.join(SCRIPTS, f".trails_cache_{name}.json")
    if os.path.exists(cache):
        print(f"  {name}: cached", file=sys.stderr)
        return json.load(open(cache)).get("elements", [])
    data = urllib.parse.urlencode({"data": overpass_query(bbox)}).encode()
    for attempt, endpoint in enumerate(OVERPASS_ENDPOINTS):
        try:
            print(f"  {name}: querying {endpoint.split('/')[2]}…", file=sys.stderr)
            req = urllib.request.Request(
                endpoint, data=data,
                headers={"User-Agent": "Chronicarum/trails (ODbL import)"})
            with urllib.request.urlopen(req, timeout=360) as resp:
                raw = json.load(resp)
            json.dump(raw, open(cache, "w"))
            print(f"  {name}: {len(raw.get('elements', []))} relations", file=sys.stderr)
            return raw.get("elements", [])
        except Exception as exc:
            print(f"  {name}: {endpoint.split('/')[2]} failed ({exc}); "
                  f"{'falling back' if attempt == 0 else 'giving up on region'}",
                  file=sys.stderr)
            time.sleep(5)
    return []   # partial coverage beats no file at all


def fetch():
    print("querying Overpass by region…", file=sys.stderr)
    by_id = {}
    for name, bbox in REGIONS.items():
        for rel in fetch_region(name, bbox):
            by_id[rel["id"]] = rel   # dedup across overlapping boxes
        time.sleep(3)               # be polite between regions
    print(f"  merged: {len(by_id)} unique relations across {len(REGIONS)} regions",
          file=sys.stderr)
    return {"elements": list(by_id.values())}


def haversine_km(a, b):
    R = 6371.0
    lat1, lon1, lat2, lon2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    dlat, dlon = lat2 - lat1, lon2 - lon1
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return 2 * R * math.asin(math.sqrt(h))


def polyline_length_km(pts):
    return sum(haversine_km(pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def point_at_half_length(pts):
    """The point nearest the midpoint by distance travelled — a fair pin for a line."""
    total = polyline_length_km(pts)
    if total == 0:
        return pts[0]
    half, run = total / 2, 0.0
    for i in range(len(pts) - 1):
        seg = haversine_km(pts[i], pts[i + 1])
        if run + seg >= half:
            return pts[i]
        run += seg
    return pts[-1]


def rdp(pts, eps):
    """Ramer-Douglas-Peucker in degree space — cheap and good enough for a display line."""
    if len(pts) < 3:
        return pts
    dmax, index = 0.0, 0
    a, b = pts[0], pts[-1]
    for i in range(1, len(pts) - 1):
        d = perpendicular_distance(pts[i], a, b)
        if d > dmax:
            dmax, index = d, i
    if dmax > eps:
        left = rdp(pts[:index + 1], eps)
        right = rdp(pts[index:], eps)
        return left[:-1] + right
    return [a, b]


def perpendicular_distance(p, a, b):
    if a == b:
        return math.hypot(p[0] - a[0], p[1] - a[1])
    num = abs((b[0] - a[0]) * (a[1] - p[1]) - (a[0] - p[0]) * (b[1] - a[1]))
    den = math.hypot(b[0] - a[0], b[1] - a[1])
    return num / den


def simplify(pts, eps):
    out = rdp(pts, eps)
    # Hard cap: if still too many points, widen epsilon until it fits.
    while len(out) > MAX_POINTS:
        eps *= 1.6
        out = rdp(pts, eps)
    return out


def encode_polyline(pts):
    """Google's encoded-polyline algorithm, precision 5. Compact; decoded in Swift."""
    result, prev_lat, prev_lon = [], 0, 0
    for lat, lon in pts:
        ilat, ilon = round(lat * 1e5), round(lon * 1e5)
        for delta in (ilat - prev_lat, ilon - prev_lon):
            delta = delta << 1
            if delta < 0:
                delta = ~delta
            while delta >= 0x20:
                result.append(chr((0x20 | (delta & 0x1f)) + 63))
                delta >>= 5
            result.append(chr(delta + 63))
        prev_lat, prev_lon = ilat, ilon
    return "".join(result)


# Tier precedence within an activity, so a merged path takes its most-national label.
TIER_RANK = {"iwn": 2, "nwn": 1, "icn": 2, "ncn": 1}


def base_name(name):
    """Strip a stage relation down to the path it belongs to.

    OSM splits long routes into a superroute parent plus per-stage child relations. The
    parents carry no ways (their members are the children), so `out geom` gives us only the
    stages — with names like "South West Coast Path (Section 28: Coverack to Helford)" or
    "EuroVelo 1 - Atlantic Coast Route - part United Kingdom 2". This recovers the path name
    they share, so the stages can be merged back into one trail.
    """
    n = re.split(r"\s*\(", name)[0]                       # drop "(Section …)"
    n = re.split(r"\s+[-–]\s*part(?:ie)?\s", n, maxsplit=1, flags=re.I)[0]  # drop "- part …"
    n = re.sub(r"\s+En projet$", "", n, flags=re.I)
    return n.strip()


def assemble(rel):
    """Concatenate member way geometries in member order into one best-effort polyline."""
    pts = []
    for m in rel.get("members", []):
        if m.get("type") != "way":
            continue
        geom = m.get("geometry")
        if not geom:
            continue
        seg = [(g["lat"], g["lon"]) for g in geom]
        if pts and seg and haversine_km(pts[-1], seg[0]) > haversine_km(pts[-1], seg[-1]):
            seg.reverse()   # join to whichever end is nearer — cheap continuity fix.
        pts.extend(seg)
    return pts


def cluster_stages(stages):
    """Group a name's stages into geographically-connected routes.

    Greedy single-link clustering on stage endpoints: a stage joins a cluster if either of
    its ends is within CLUSTER_GAP_KM of any endpoint already in that cluster. Longest
    stages placed first, so a cluster grows from its trunk outward.
    """
    clusters = []   # each: {"stages": [...], "ends": [(lat,lon), ...]}
    for stage in sorted(stages, key=lambda s: -s["km"]):
        ends = [stage["poly"][0], stage["poly"][-1]]
        home = None
        for cl in clusters:
            if any(haversine_km(pe, ce) <= CLUSTER_GAP_KM
                   for pe in ends for ce in cl["ends"]):
                home = cl
                break
        if home is None:
            clusters.append({"stages": [stage], "ends": list(ends)})
        else:
            home["stages"].append(stage)
            home["ends"].extend(ends)
    return [cl["stages"] for cl in clusters]


def build():
    raw = fetch()
    elements = raw.get("elements", [])
    print(f"  {len(elements)} route relations returned", file=sys.stderr)

    # First pass: one segment per qualifying relation.
    segments = []   # (base, activity, tier, km, simplified_points, rel_id)
    for rel in elements:
        tags = rel.get("tags", {})
        name = tags.get("name", "").strip()
        activity = ACTIVITY.get(tags.get("route", ""))
        network = tags.get("network", "")
        if not name or not activity or network not in KEEP_NETWORK:
            continue
        pts = assemble(rel)
        if len(pts) < 2:
            continue
        km = polyline_length_km(pts)
        if km <= 0:
            continue
        segments.append((base_name(name), activity, network, km,
                         simplify(pts, RDP_EPSILON_DEG), rel["id"]))

    # Second pass: gather stages that share a base name + activity.
    groups = {}
    for base, activity, network, km, simplified, rel_id in segments:
        groups.setdefault((base, activity), []).append(
            {"tier": network, "km": km, "poly": simplified, "id": rel_id})

    # Third pass: split each name-group into geographically-connected clusters, then emit one
    # trail per cluster. Within Great Britain a shared name meant one route; across a
    # continent it can mean two unrelated "Coastal Path"s a thousand km apart, which must not
    # merge into a single impossible trail. Stages within CLUSTER_GAP_KM of each other are
    # the same route; a bigger jump starts a new one.
    trails = []
    for (base, activity), stages in groups.items():
        for cluster in cluster_stages(stages):
            km_total = sum(s["km"] for s in cluster)
            if not (MIN_KM <= km_total <= MAX_KM):
                continue
            longest = max(cluster, key=lambda s: s["km"])
            mid = point_at_half_length(longest["poly"])
            tier = max((s["tier"] for s in cluster),
                       key=lambda t: TIER_RANK.get(t, 0))
            trails.append({
                "id": f"trail/{longest['id']}",
                "name": base,
                "activity": activity,
                "tier": tier,
                "km": round(km_total, 1),
                "lat": round(mid[0], 6),
                "lon": round(mid[1], 6),
                # Segments joined by ';' — safe, below the encoded-polyline alphabet (63+).
                "poly": ";".join(encode_polyline(s["poly"]) for s in cluster),
            })
    trails.sort(key=lambda t: -t["km"])

    columns = {k: [t[k] for t in trails]
               for k in ("id", "name", "activity", "tier", "km", "lat", "lon", "poly")}
    with open(OUT, "w") as f:
        json.dump(columns, f, ensure_ascii=False, separators=(",", ":"))

    size_kb = os.path.getsize(OUT) / 1024
    walk = sum(1 for a in columns["activity"] if a == "walk")
    bike = len(trails) - walk
    print(f"wrote {len(trails)} trails ({walk} walk, {bike} bike) "
          f"-> {OUT} ({size_kb:.0f} KB)", file=sys.stderr)


if __name__ == "__main__":
    build()
