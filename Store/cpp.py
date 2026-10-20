"""Custom product pages: one per audience, each with its own screenshots and promotional text.

    python Store/cpp.py <frames root>     frames root holds cpp-idle/, cpp-widgets/, cpp-chaos/ (Store/art/frame.mjs)
    python Store/cpp.py status

Idempotent: reuses a page with the same name and replaces its screenshots when they differ.
"""
import hashlib
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

PAGES = [
    ("cpp-idle", "Idle players", "A gift every day, a new Season every month, 24 stamps to collect. Seven tiny people run the town while you are away; check in and meddle."),
    ("cpp-widgets", "Home Screen widgets", "Put a living town on your Home Screen. Town Square shows the whole yard, who holds the Crown and who is in jail, with a refresh button."),
    ("cpp-chaos", "God game chaos", "Crown anyone, jail anyone, drop a plague of frogs, pass Martial Law. Seven tiny people, one town, no supervision whatsoever."),
]
DISPLAY = "APP_IPHONE_67"


def pages(aid):
    return (asc.call("GET", f"/v1/apps/{aid}/appCustomProductPages", params={"limit": 50}) or {"data": []})["data"]


def ensure(aid, name, promo):
    for p in pages(aid):
        if p["attributes"]["name"] == name:
            return p
    made = asc.call("POST", "/v1/appCustomProductPages", {
        "data": {"type": "appCustomProductPages", "attributes": {"name": name},
                 "relationships": {"app": {"data": {"type": "apps", "id": aid}},
                                   "appCustomProductPageVersions": {"data": [{"type": "appCustomProductPageVersions", "id": "${v1}"}]}}},
        "included": [
            {"type": "appCustomProductPageVersions", "id": "${v1}",
             "relationships": {"appCustomProductPageLocalizations": {"data": [{"type": "appCustomProductPageLocalizations", "id": "${l1}"}]}}},
            {"type": "appCustomProductPageLocalizations", "id": "${l1}", "attributes": {"locale": "en-US", "promotionalText": promo}},
        ]})
    return made["data"] if made else None


def localization(page):
    vers = asc.call("GET", f"/v1/appCustomProductPages/{page['id']}/appCustomProductPageVersions", params={"limit": 10})["data"]
    v = vers[-1]
    locs = asc.call("GET", f"/v1/appCustomProductPageVersions/{v['id']}/appCustomProductPageLocalizations", params={"limit": 50})["data"]
    return v, next(l for l in locs if l["attributes"]["locale"] == "en-US")


def shots(loc, files):
    sets = asc.call("GET", f"/v1/appCustomProductPageLocalizations/{loc['id']}/appScreenshotSets")["data"]
    sset = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == DISPLAY), None)
    local = [hashlib.md5(f.read_bytes()).hexdigest() for f in files]
    if sset:
        remote = [s["attributes"].get("sourceFileChecksum") for s in asc.call("GET", f"/v1/appScreenshotSets/{sset['id']}/appScreenshots", params={"limit": 20})["data"]]
        if remote == local:
            return "MATCH"
        for s in asc.call("GET", f"/v1/appScreenshotSets/{sset['id']}/appScreenshots", params={"limit": 20})["data"]:
            asc.call("DELETE", f"/v1/appScreenshots/{s['id']}")
    else:
        sset = asc.call("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": DISPLAY},
                        "relationships": {"appCustomProductPageLocalization": {"data": {"type": "appCustomProductPageLocalizations", "id": loc["id"]}}}}})["data"]
    for f in files:
        data = f.read_bytes()
        made = asc.call("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots", "attributes": {"fileName": f.name, "fileSize": len(data)},
                        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sset["id"]}}}}})["data"]
        for op in made["attributes"]["uploadOperations"]:
            h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
            requests.request(op["method"], op["url"], headers=h, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
        asc.call("PATCH", f"/v1/appScreenshots/{made['id']}", {"data": {"type": "appScreenshots", "id": made["id"],
                 "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    return f"uploaded {len(files)}"


def main(root):
    aid = asc.find_app()["id"]
    for key, name, promo in PAGES:
        page = ensure(aid, name, promo)
        if not page:
            print(name, "create FAILED"); continue
        v, loc = localization(page)
        asc.call("PATCH", f"/v1/appCustomProductPageLocalizations/{loc['id']}", {"data": {"type": "appCustomProductPageLocalizations", "id": loc["id"], "attributes": {"promotionalText": promo}}})
        res = shots(loc, sorted((Path(root) / key).glob("*.png")))
        print(f"{name}: page {page['id']} version {v['id']} {v['attributes'].get('state')} screenshots {res}")
        print(f"  url: {page['attributes'].get('url')}")


def status():
    aid = asc.find_app()["id"]
    for p in pages(aid):
        v, _ = localization(p)
        print(p["attributes"]["name"], p["id"], v["id"], v["attributes"].get("state"), p["attributes"].get("url"))


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "status":
        status()
    else:
        main(sys.argv[1])
