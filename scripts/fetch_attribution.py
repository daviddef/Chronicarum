"""Fetch author + licence for every Commons photo the app displays.

CC BY-SA — which covers most of these images — requires naming the author. Linking to the
file page is good faith; this makes the credit explicit. Commons' imageinfo API takes 50
titles per request, so ~22k photos is ~450 calls.

Output: attribution.json — {filename: {"a": artist, "l": licence}}, kept in its own file
so it can be loaded lazily rather than bloating the main site bundle."""
import html, json, re, subprocess, sys, time

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
UA = "ChronicarumHeritageApp/0.1 (david.defranceski@gmail.com)"
API = "https://commons.wikimedia.org/w/api.php"
BATCH = 50

def clean(raw):
    """Artist arrives as HTML (often an anchor tag). Reduce to plain text."""
    if not raw:
        return None
    text = re.sub(r"<[^>]+>", "", raw)
    text = html.unescape(text).strip()
    text = re.sub(r"\s+", " ", text)
    return text[:120] or None

# Every distinct filename the app can show.
files = set()
for row in json.load(open(f"{SP}/bulk_sites.json")):
    if row.get("img"):
        files.add(row["img"])
files.update(json.load(open(f"{SP}/featured_images.json")).values())
files = sorted(files)

out = {}
try:
    out = json.load(open(f"{SP}/attribution.json"))
except Exception:
    pass
todo = [f for f in files if f not in out]
print(f"{len(files)} photos, {len(todo)} still to fetch", flush=True)

for i in range(0, len(todo), BATCH):
    chunk = todo[i:i + BATCH]
    titles = "|".join("File:" + f for f in chunk)
    params = ["action=query", "format=json", "prop=imageinfo",
              "iiprop=extmetadata", "iiextmetadatafilter=Artist|LicenseShortName"]
    proc = subprocess.run(
        ["curl", "-sS", "--max-time", "90", "-G", API,
         *sum((["--data-urlencode", p] for p in params), []),
         "--data-urlencode", f"titles={titles}",
         "-H", f"User-Agent: {UA}"], capture_output=True, text=True)
    try:
        pages = json.loads(proc.stdout)["query"]["pages"]
    except Exception:
        sys.stderr.write(f"  ! batch {i//BATCH} failed\n")
        time.sleep(3)
        continue

    for page in pages.values():
        title = page.get("title", "")
        if not title.startswith("File:"):
            continue
        name = title[5:]
        info = (page.get("imageinfo") or [{}])[0].get("extmetadata", {})
        artist = clean(info.get("Artist", {}).get("value"))
        licence = clean(info.get("LicenseShortName", {}).get("value"))
        if artist or licence:
            entry = {}
            if artist:  entry["a"] = artist
            if licence: entry["l"] = licence
            out[name] = entry

    if (i // BATCH) % 25 == 0:
        json.dump(out, open(f"{SP}/attribution.json", "w"), ensure_ascii=False)
        print(f"  {i + len(chunk)}/{len(todo)} — {len(out)} credited", flush=True)
    time.sleep(0.3)

json.dump(out, open(f"{SP}/attribution.json", "w"), ensure_ascii=False)
print(f"done: {len(out)} photos have author/licence")
