"""Town Club: the auto-renewable subscription group, its two plans, the free week and everything Apple wants.

    python Store/club.py create            group + localizations, both plans, prices in every territory,
                                           availability, the yearly free week (idempotent)
    python Store/club.py shot <png>        App Review screenshot for both plans
    python Store/club.py image <png>       1024x1024 promotional image for both plans
    python Store/club.py status
"""
import hashlib
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

GROUP = "Town Club"
GROUP_LOCS = {  # locale: (group display name, custom app name or None)
    "en-US": ("Town Club", None),
}
NOTE = (
    "Auto-renewable subscription, group 'Town Club', two plans (monthly and yearly; yearly has a one-week free trial "
    "for new subscribers). Where: the title screen link 'The Town Club: more every month', Start menu > Town Club, "
    "or tap any locked item (a locked meddle on a character card, the locked RENAME, a Club miracle, the Club row of "
    "the Season, the Almanac). The Club window shows both plans with price, period, trial terms and auto-renewal "
    "text, Terms of Use (Apple standard EULA) and Privacy Policy links, RESTORE, REDEEM CODE, and MANAGE SUBSCRIPTION "
    "for members. What members get, all of it real in this build: everything in The Big Hand (the separate one-time "
    "purchase, untouched), a Club Chest every calendar month (25 miracles + 5 invitations, button in the Club window), "
    "doubled daily gifts, the Club row of every monthly Season (Start > Season), two Club miracles (Tax Holiday, "
    "Crime Wave), every yard, the Town Almanac charts (Start > Town almanac), and iCloud key-value backup of the town "
    "(Start > Settings). Everything that was free stays free. No account, no server."
)
PLANS = [
    # suffix, period, reference name, price, display name, description (<=55)
    ("club.monthly", "ONE_MONTH", "Town Club Monthly", "2.99", "Town Club (Monthly)", "Monthly chest, double gifts, every yard, Club Season."),
    ("club.yearly", "ONE_YEAR", "Town Club Yearly", "14.99", "Town Club (Yearly)", "Monthly chests all year, double gifts, every yard."),
]
BASE = "com.mattbusel.pocketbeings."


def app_id():
    return asc.find_app()["id"]


def group():
    aid = app_id()
    got = asc.call("GET", f"/v1/apps/{aid}/subscriptionGroups", params={"limit": 20})
    for g in (got or {}).get("data", []):
        if g["attributes"]["referenceName"] == GROUP:
            return g
    made = asc.call("POST", "/v1/subscriptionGroups", {"data": {"type": "subscriptionGroups", "attributes": {"referenceName": GROUP},
                    "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}})
    return made["data"]


def find(gid, pid):
    got = asc.call("GET", f"/v1/subscriptionGroups/{gid}/subscriptions", params={"limit": 20})
    for s in (got or {}).get("data", []):
        if s["attributes"]["productId"] == pid:
            return s
    return None


def group_locs(gid, locs=GROUP_LOCS):
    have = asc.call("GET", f"/v1/subscriptionGroups/{gid}/subscriptionGroupLocalizations", params={"limit": 50}) or {"data": []}
    by = {l["attributes"]["locale"]: l for l in have["data"]}
    for loc, (name, app_name) in locs.items():
        attrs = {"name": name}
        if app_name:
            attrs["customAppName"] = app_name
        if loc in by:
            asc.call("PATCH", f"/v1/subscriptionGroupLocalizations/{by[loc]['id']}", {"data": {"type": "subscriptionGroupLocalizations", "id": by[loc]["id"], "attributes": attrs}})
        else:
            r = asc.call("POST", "/v1/subscriptionGroupLocalizations", {"data": {"type": "subscriptionGroupLocalizations", "attributes": {"locale": loc, **attrs},
                         "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": gid}}}}})
            print("  group loc", loc, "added" if r else "FAILED")


def sub_locs(sid, locs):
    have = asc.call("GET", f"/v1/subscriptions/{sid}/subscriptionLocalizations", params={"limit": 50}) or {"data": []}
    by = {l["attributes"]["locale"]: l for l in have["data"]}
    for loc, (name, desc) in locs.items():
        if loc in by:
            asc.call("PATCH", f"/v1/subscriptionLocalizations/{by[loc]['id']}", {"data": {"type": "subscriptionLocalizations", "id": by[loc]["id"], "attributes": {"name": name, "description": desc}}})
        else:
            r = asc.call("POST", "/v1/subscriptionLocalizations", {"data": {"type": "subscriptionLocalizations", "attributes": {"locale": loc, "name": name, "description": desc},
                         "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})
            print("  loc", loc, "added" if r else "FAILED")


def prices(sid, price):
    have = asc.call("GET", f"/v1/subscriptions/{sid}/prices", params={"limit": 200}) or {"data": []}
    if len(have["data"]) >= 150:
        print(f"  prices already set ({len(have['data'])} territories)")
        return
    pts = asc.call("GET", f"/v1/subscriptions/{sid}/pricePoints", params={"filter[territory]": "USA", "limit": 8000})
    usa = next((p for p in (pts or {}).get("data", []) if p["attributes"]["customerPrice"] == price), None)
    if not usa:
        sys.exit(f"no USA subscription price point at {price}")
    points = [usa["id"]]
    url = f"/v1/subscriptionPricePoints/{usa['id']}/equalizations"
    params = {"limit": 200}
    while url:
        got = asc.call("GET", url, params=params) or {}
        points += [p["id"] for p in got.get("data", [])]
        url = (got.get("links") or {}).get("next")
        params = None
    ok = 0
    for pp in points:
        r = asc.call("POST", "/v1/subscriptionPrices", {"data": {"type": "subscriptionPrices", "attributes": {"startDate": None, "preserveCurrentPrice": False},
                     "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                       "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": pp}}}}}, quiet=True)
        ok += 1 if r is not None else 0
    print(f"  prices: {ok}/{len(points)} territories at USD {price} equivalent")


def availability(sid):
    have = asc.call("GET", f"/v1/subscriptions/{sid}/subscriptionAvailability", quiet=True)
    if have and have.get("data"):
        print("  availability exists")
        return
    terr = [t["id"] for t in asc.call("GET", "/v1/territories", params={"limit": 200})["data"]]
    r = asc.call("POST", "/v1/subscriptionAvailabilities", {"data": {"type": "subscriptionAvailabilities", "attributes": {"availableInNewTerritories": True},
                 "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                   "availableTerritories": {"data": [{"type": "territories", "id": t} for t in terr]}}}})
    print("  availability", f"{len(terr)} territories" if r else "FAILED")


def free_week(sid):
    have = asc.call("GET", f"/v1/subscriptions/{sid}/introductoryOffers", params={"limit": 200}) or {"data": []}
    if have["data"]:
        print(f"  introductory offers exist ({len(have['data'])})")
        return
    body = {"data": {"type": "subscriptionIntroductoryOffers",
                     "attributes": {"duration": "ONE_WEEK", "offerMode": "FREE_TRIAL", "numberOfPeriods": 1, "startDate": None, "endDate": None},
                     "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}}
    r = asc.call("POST", "/v1/subscriptionIntroductoryOffers", body)
    if r:
        print("  free week: added (all territories)")
        return
    # Fall back to one offer per territory.
    terr = [t["id"] for t in asc.call("GET", "/v1/territories", params={"limit": 200})["data"]]
    ok = 0
    for t in terr:
        body["data"]["relationships"]["territory"] = {"data": {"type": "territories", "id": t}}
        ok += 1 if asc.call("POST", "/v1/subscriptionIntroductoryOffers", body, quiet=True) else 0
    print(f"  free week: {ok}/{len(terr)} territories")


def create():
    g = group()
    gid = g["id"]
    print(f"group {GROUP}: {gid}")
    group_locs(gid)
    for suffix, period, ref, price, name, desc in PLANS:
        pid = BASE + suffix
        s = find(gid, pid)
        if not s:
            made = asc.call("POST", "/v1/subscriptions", {"data": {"type": "subscriptions", "attributes": {
                "name": ref, "productId": pid, "subscriptionPeriod": period, "familySharable": False, "reviewNote": NOTE, "groupLevel": 1},
                "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": gid}}}}})
            if not made:
                print(f"{pid}: create FAILED"); continue
            s = made["data"]
        sid = s["id"]
        asc.call("PATCH", f"/v1/subscriptions/{sid}", {"data": {"type": "subscriptions", "id": sid, "attributes": {"reviewNote": NOTE}}})
        print(f"{pid}: {sid} {s['attributes'].get('state')}")
        sub_locs(sid, {"en-US": (name, desc)})
        prices(sid, price)
        availability(sid)
        if period == "ONE_YEAR":
            free_week(sid)


def upload(kind, png):
    data = Path(png).read_bytes()
    gid = group()["id"]
    for suffix, *_ in PLANS:
        s = find(gid, BASE + suffix)
        if not s:
            continue
        sid = s["id"]
        if kind == "shot":
            cur = asc.call("GET", f"/v1/subscriptions/{sid}/appStoreReviewScreenshot", quiet=True)
            if cur and cur.get("data"):
                asc.call("DELETE", f"/v1/subscriptionAppStoreReviewScreenshots/{cur['data']['id']}")
            typ, rel = "subscriptionAppStoreReviewScreenshots", "subscription"
        else:
            cur = asc.call("GET", f"/v1/subscriptions/{sid}/images", quiet=True) or {"data": []}
            for im in cur.get("data", []):
                asc.call("DELETE", f"/v1/subscriptionImages/{im['id']}")
            typ, rel = "subscriptionImages", "subscription"
        made = asc.call("POST", f"/v1/{typ}", {"data": {"type": typ, "attributes": {"fileName": Path(png).name, "fileSize": len(data)},
                        "relationships": {rel: {"data": {"type": "subscriptions", "id": sid}}}}})
        if not made:
            print(suffix, kind, "reserve FAILED"); continue
        mid = made["data"]["id"]
        for op in made["data"]["attributes"]["uploadOperations"]:
            headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
            requests.request(op["method"], op["url"], headers=headers, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
        r = asc.call("PATCH", f"/v1/{typ}/{mid}", {"data": {"type": typ, "id": mid,
                     "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print(suffix, kind, "uploaded" if r else "FAILED")


def status():
    gid = group()["id"]
    for suffix, *_ in PLANS:
        s = find(gid, BASE + suffix)
        print(f"{BASE + suffix}: {s['id'] + ' ' + s['attributes']['state'] if s else 'missing'}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd in ("shot", "image"):
        upload(cmd, sys.argv[2])
    else:
        {"create": create, "status": status}.get(cmd, lambda: sys.exit(__doc__))()
