"""Score every site on whether it is worth a detour.

## Why this and not containment

Containment was supposed to fix "central Split needs 48 hours for one afternoon". It did
not: it removed 2 hours. The catalogue genuinely holds 52 heritage records within 400 m of
Split's centre, and a person visits about six of them. The problem was never double
counting — it is that **nothing decides which six**.

Every stage of the itinerary depends on this. You cannot shape a day out of 52 equal
things, and ranking by distance alone gives you six listed townhouses on the same street
while the cathedral sits 300 m away.

## The signals, and one reversal

The strongest is **Wikipedia sitelink count**, which is where this project started and got
badly wrong. The first import required ≥5 language editions and left Brisbane with 7 sites
and Dubrovnik with 1. That was the wrong filter — but it is the right *ranker*.

Nothing about "how many Wikipedias describe this" says whether a place belongs in a
heritage catalogue; that is what a government register is for. But once every designated
place is in, sitelinks measure very well which of them a visitor has heard of. Croatia by
sitelinks: Plitvice 70, Diocletian's Palace 52, Bakarski Castle 0. Exactly right for
choosing six places; exactly wrong for choosing 260,008.

Sitelinks only exist for the ~140k rows carrying a Wikidata QID, so **a missing count is
never evidence of unimportance** — it contributes a bonus or nothing. The register-sourced
rows are carried by their own grades instead: Grade I, Category A, National Historic
Landmark. Every source therefore has *some* route to a high score.

Scores are 0–100 and are a **ranking device, not a judgement**. A 12 is not "unimportant";
it is "if you only have a day, not this one".
"""
import json, math, re, unicodedata
from collections import Counter

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
BUNDLE = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Resources/bulk_sites.json"

# Weights sum to 100. Renown dominates because it is the only signal that reflects what a
# visitor has actually heard of; everything else describes the record, not the place.
W_RENOWN, W_GRADE, W_SUBSTANCE, W_WHOLENESS, W_NAME = 40, 25, 20, 10, 5

TOP_GRADES = {"Grade I", "Category A (Scotland)"}
MID_GRADES = {"Grade II*", "Category B (Scotland)", "Scheduled monument"}

GENERIC_NAME = re.compile(
    r"^(?:the\s+)?(?:house|houses|building|buildings|immeuble|maison|cottage|barn|shop"
    r"|dwelling|store|warehouse|terrace|villa|hall|farmhouse|outbuilding|wall|walls"
    r"|bridge|church|chapel|eglise|monument|memorial|statue|cross|well|school)\W*$",
    re.I)

WORLD_HERITAGE = re.compile(r"world heritage|unesco", re.I)


def fold(text):
    text = unicodedata.normalize("NFKD", text.lower())
    return "".join(c for c in text if not unicodedata.combining(c))


def renown_points(sitelinks):
    """Log-scaled: the step from 2 to 8 languages says far more than 60 to 66.

    Capped at 50 sitelinks, above which everything is simply famous — the Colosseum and
    the Eiffel Tower do not need separating for the purpose of filling a Tuesday."""
    if sitelinks <= 1:
        return 0.0
    return W_RENOWN * min(1.0, math.log(sitelinks) / math.log(50))


def grade_points(site, grade, is_nhl):
    text = fold(site["name"] + " " + (site.get("desc") or ""))
    if WORLD_HERITAGE.search(text):
        return W_GRADE
    if is_nhl or grade in TOP_GRADES:
        return W_GRADE * 0.8
    if grade in MID_GRADES:
        return W_GRADE * 0.4
    return 0.0


def substance_points(site):
    """What the catalogue actually holds about the place. A site with a photograph and
    real prose is one somebody cared enough to document."""
    points = 0.0
    if site.get("img"):
        points += W_SUBSTANCE * 0.4
    desc = (site.get("desc") or "").strip()
    # An address is not a description. Register rows fall back to one, and it should not
    # count as substance.
    if len(desc) > 25 and not re.match(r"^\d+[a-z]?\s", desc):
        points += W_SUBSTANCE * 0.35
    if site.get("dur", 0) >= 60:
        points += W_SUBSTANCE * 0.25
    return points


def name_points(site):
    return 0.0 if GENERIC_NAME.match(site["name"].strip()) else W_NAME


def main():
    sites = json.load(open(BUNDLE))

    sitelinks = json.load(open(f"{SP}/sitelinks.json"))
    uk = {"wd-" + r["qid"]: r.get("grade") for r in json.load(open(f"{SP}/heritage_uk.json"))}
    nhl = {"nrhp-" + r["ref"] for r in json.load(open(f"{SP}/heritage_us.json")) if r.get("nhl")}

    # A site holding parts is a destination; a part is something you see once there.
    child_count = Counter(s["par"] for s in sites if s.get("par"))

    for site in sites:
        qid = site["id"][3:] if site["id"].startswith("wd-") else None
        links = sitelinks.get(qid, 0) if qid else 0

        grade = grade_points(site, uk.get(site["id"]), site["id"] in nhl)
        renown = renown_points(links)

        # Renown needs corroboration. Sitelinks measure what Wikipedia covers, which
        # includes football stadiums, airports and universities — Stadion Poljud ranked
        # fourth in Split on 40 sitelinks and nothing else. A site with no theme, no
        # grade and no description has given us no evidence it is a heritage destination
        # at all, only that it is known, so its renown is heavily discounted rather than
        # trusted outright.
        corroborated = site.get("th") or grade > 0 or len((site.get("desc") or "").strip()) > 25
        if not corroborated:
            renown *= 0.25

        score = renown + grade + substance_points(site) + name_points(site)

        if child_count.get(site["id"]):
            score += W_WHOLENESS
        elif site.get("par"):
            # You will see it while visiting the parent; it should not compete with it.
            score -= W_WHOLENESS

        site["sig"] = max(0, min(100, round(score)))

    json.dump(sites, open(BUNDLE, "w"), ensure_ascii=False, separators=(",", ":"))

    scores = [s["sig"] for s in sites]
    print(f"{len(sites)} sites scored\n")
    buckets = Counter(min(90, s // 10 * 10) for s in scores)
    for low in sorted(buckets):
        n = buckets[low]
        print(f"  {low:>3}-{low + 9:<3} {n:>7}  {'█' * max(1, n * 40 // len(sites))}")
    print(f"\n  mean {sum(scores) / len(scores):.1f}, "
          f"top 1% scores {sorted(scores)[int(len(scores) * 0.99)]}+")


if __name__ == "__main__":
    main()
