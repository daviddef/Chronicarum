"""Merge the per-category Wikidata pulls into one compact bundle:
dedupe across categories and against the curated sites, map era from inception."""
import json, re, glob

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
CURATED = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Models/SiteData.swift"

STYPE = {"castle": "castle", "museum": "museum", "unesco": "heritage"}

def era_from_inception(iso):
    """Wikidata P571 → an era bucket. Handles BC via a leading '-'."""
    if not iso:
        return "unknown"
    m = re.match(r"(-?)(\d+)-", iso)
    if not m:
        return "unknown"
    year = int(m.group(2)) * (-1 if m.group(1) == "-" else 1)
    if year < -500:  return "ancient"
    if year < 500:   return "classical"
    if year < 1400:  return "medieval"
    if year < 1750:  return "renaissance"
    return "modern"

def norm(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())

# Curated sites: collect names + coords so bulk duplicates defer to the rich version.
src = open(CURATED).read()
cur_names, cur_coords = set(), []
for blk in re.split(r"\n        Site\(", src)[1:]:
    n = re.search(r'name: "([^"]+)"', blk)
    la = re.search(r"latitude: (-?[\d.]+)", blk)
    lo = re.search(r"longitude: (-?[\d.]+)", blk)
    if n:  cur_names.add(norm(n.group(1)))
    if la and lo: cur_coords.append((float(la.group(1)), float(lo.group(1))))

def collides_curated(s):
    if norm(s["name"]) in cur_names:
        return True
    for cla, clo in cur_coords:
        if abs(s["lat"] - cla) < 0.01 and abs(s["lon"] - clo) < 0.01:
            return True
    return False

# Category precedence when the same QID appears in several pulls: a castle that is also
# a WHS should read as a castle, not a generic heritage site.
PRIORITY = {"castle": 0, "museum": 1, "unesco": 2}
by_qid = {}
for f in sorted(glob.glob(f"{SP}/bulk_*.json")):
    for r in json.load(open(f)):
        q = r["qid"]
        if q not in by_qid or PRIORITY[r["stype"]] < PRIORITY[by_qid[q]["stype"]]:
            by_qid[q] = r

out, dropped_cur, dropped_thin = [], 0, 0
for r in by_qid.values():
    if collides_curated(r):
        dropped_cur += 1
        continue
    # A bare name pin with neither country nor description is too thin to be worth showing.
    if not r.get("country") and not r.get("desc"):
        dropped_thin += 1
        continue
    out.append({
        "id":   "wd-" + r["qid"],
        "name": r["name"],
        "lat":  r["lat"],
        "lon":  r["lon"],
        "type": STYPE[r["stype"]],
        "era":  era_from_inception(r.get("inception")),
        "country": r.get("country") or "",
        "desc": (r.get("desc") or "").strip(),
    })

out.sort(key=lambda s: s["id"])
json.dump(out, open(f"{SP}/bulk_sites.json", "w"), ensure_ascii=False, separators=(",", ":"))

from collections import Counter
print(f"bulk sites written: {len(out)}")
print(f"  dropped {dropped_cur} colliding with curated, {dropped_thin} too thin")
print("  by type:", dict(Counter(s['type'] for s in out)))
print("  by era: ", dict(Counter(s['era'] for s in out)))
print(f"  file size: {len(open(f'{SP}/bulk_sites.json').read())//1024} KB")
