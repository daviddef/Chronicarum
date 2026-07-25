"""Extract named national/international walking and cycling routes from OpenStreetMap.

The outdoor layer. Everything else in the catalogue is a *point* — a place you stand in
front of. A trail is a *line* you travel along for its own sake, so it is its own record,
not a bent `Site`. See ROADMAP.md "The outdoors — trails, walks, bike rides".

Source and licence: OpenStreetMap route relations, ODbL. The extracted geometry shipped in
the app is a Derivative Database, so it must be attributed to OSM and offered under ODbL on
request — which is why it lives in its OWN bundled file (`trails.json`), a collective
database kept separate from the heritage catalogue rather than merged into it. The Overpass
query below IS the "means of creating" we offer on request.

First cut, deliberately: **national and international named routes only** (`network` in
iwn/nwn for walking, icn/ncn for cycling). Local footpaths run to millions and would drown
the signal exactly as the unfiltered heritage import did; the network tier is the
significance filter all over again. Pilot bbox: Great Britain.

Output is columnar, mirroring `build_columnar.py`, and small enough to bundle without LFS:
each trail's geometry is simplified (Ramer-Douglas-Peucker) and stored as a precision-5
encoded polyline.

Stdlib only — no third-party deps, same as the other fetch scripts.
"""
import json, os, math, re, urllib.request, urllib.parse, sys

RESOURCES = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Chronicarum/Resources")
OUT = f"{RESOURCES}/trails.json"

OVERPASS = "https://overpass-api.de/api/interpreter"

# Great Britain, roughly. south, west, north, east.
BBOX = (49.8, -8.7, 61.1, 2.1)

# route -> our activity bucket. Walking and cycling only for the first cut; horse/ski/canoe
# routes are real OSM route types but not what "out for a walk / on two wheels" asks for.
ACTIVITY = {"hiking": "walk", "foot": "walk", "bicycle": "bike", "mtb": "bike"}
# The tiers we keep, per activity — national and international only.
KEEP_NETWORK = {"iwn", "nwn", "icn", "ncn"}

MIN_KM, MAX_KM = 2.0, 5000.0
RDP_EPSILON_DEG = 0.0006   # ~65 m; enough to hold the shape of a long path cheaply.
MAX_POINTS = 90            # cap per trail so one monster relation can't bloat the bundle.


def overpass_query():
    routes = "|".join(sorted(ACTIVITY))
    nets = "|".join(sorted(KEEP_NETWORK))
    s, w, n, e = BBOX
    return f"""
[out:json][timeout:240];
(
  relation["route"~"^({routes})$"]["network"~"^({nets})$"]["name"]({s},{w},{n},{e});
);
out geom;
"""


CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".trails_raw_cache.json")


def fetch():
    # Cache the raw Overpass response so re-runs while tuning the filters don't re-query.
    # Delete scripts/.trails_raw_cache.json to force a fresh pull.
    if os.path.exists(CACHE):
        print("using cached Overpass response (delete .trails_raw_cache.json to refresh)",
              file=sys.stderr)
        return json.load(open(CACHE))
    query = overpass_query()
    print("querying Overpass for GB national/international routes…", file=sys.stderr)
    data = urllib.parse.urlencode({"data": query}).encode()
    req = urllib.request.Request(OVERPASS, data=data,
                                 headers={"User-Agent": "Chronicarum/trails (ODbL import)"})
    with urllib.request.urlopen(req, timeout=300) as resp:
        raw = json.load(resp)
    json.dump(raw, open(CACHE, "w"))
    return raw


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

    # Second pass: merge stages that share a base name + activity into one multi-segment
    # trail. Each stage stays its own polyline, so out-of-order sections never draw a line
    # jumping across the map between them.
    groups = {}
    for base, activity, network, km, simplified, rel_id in segments:
        g = groups.setdefault((base, activity), {
            "tier": network, "km": 0.0, "polys": [], "longest": (0.0, None), "id": rel_id})
        if TIER_RANK.get(network, 0) > TIER_RANK.get(g["tier"], 0):
            g["tier"] = network
        g["km"] += km
        g["polys"].append(simplified)
        if km > g["longest"][0]:
            g["longest"] = (km, simplified)

    trails = []
    for (base, activity), g in groups.items():
        if not (MIN_KM <= g["km"] <= MAX_KM):
            continue
        mid = point_at_half_length(g["longest"][1])   # pin the busiest stretch
        trails.append({
            "id": f"trail/{g['id']}",
            "name": base,
            "activity": activity,
            "tier": g["tier"],
            "km": round(g["km"], 1),
            "lat": round(mid[0], 6),
            "lon": round(mid[1], 6),
            # Segments joined by ';' — safe, it's below the encoded-polyline alphabet (63+).
            "poly": ";".join(encode_polyline(p) for p in g["polys"]),
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
