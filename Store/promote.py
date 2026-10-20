"""Promoted in-app purchases: 1024x1024 images on the products, then promotedPurchases on the product page.

    python Store/promote.py images      upload promo images (yards use their own app icons)
    python Store/promote.py promote     promote Club yearly, Club monthly, Night Market, Miracle Jar, Season Boost
    python Store/promote.py status
"""
import hashlib
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402
import club  # noqa: E402
import iap2  # noqa: E402

ROOT = Path(__file__).resolve().parent
ICONS = ROOT.parent / "Resources" / "Assets.xcassets"
IMAGES = {
    "miracles5": ROOT / "art/promo/jar.png",
    "boost": ROOT / "art/promo/boost.png",
    "yard.snow": ICONS / "AppIcon-SnowDay.appiconset/icon-1024.png",
    "yard.night": ICONS / "AppIcon-NightMarket.appiconset/icon-1024.png",
    "yard.beach": ICONS / "AppIcon-BeachTown.appiconset/icon-1024.png",
    "yard.mars": ICONS / "AppIcon-MarsColony.appiconset/icon-1024.png",
}


def put(typ, rel, rel_type, rid, f):
    data = f.read_bytes()
    made = asc.call("POST", f"/v1/{typ}", {"data": {"type": typ, "attributes": {"fileName": f.name, "fileSize": len(data)},
                    "relationships": {rel: {"data": {"type": rel_type, "id": rid}}}}})
    if not made:
        return False
    mid = made["data"]["id"]
    for op in made["data"]["attributes"]["uploadOperations"]:
        h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
        requests.request(op["method"], op["url"], headers=h, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
    return asc.call("PATCH", f"/v1/{typ}/{mid}", {"data": {"type": typ, "id": mid,
                    "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}}) is not None


def images():
    for suffix, f in IMAGES.items():
        it = iap2.find(iap2.BASE + suffix)
        cur = asc.call("GET", f"/v2/inAppPurchases/{it['id']}/images", quiet=True) or {"data": []}
        if cur.get("data"):
            print(suffix, "image exists"); continue
        print(suffix, "image", "uploaded" if put("inAppPurchaseImages", "inAppPurchase", "inAppPurchases", it["id"], f) else "FAILED")


def promote():
    aid = asc.find_app()["id"]
    gid = club.group()["id"]
    have = asc.call("GET", f"/v1/apps/{aid}/promotedPurchases", params={"limit": 50, "include": "inAppPurchaseV2,subscription"}) or {"data": []}
    taken = set()
    for p in have["data"]:
        for k in ("inAppPurchaseV2", "subscription"):
            d = (p["relationships"].get(k) or {}).get("data")
            if d:
                taken.add(d["id"])
    order = []
    for suffix in ("club.yearly", "club.monthly"):
        s = club.find(gid, club.BASE + suffix)
        order.append(("subscription", "subscriptions", s["id"], suffix))
    for suffix in ("yard.night", "miracles5", "boost"):
        it = iap2.find(iap2.BASE + suffix)
        order.append(("inAppPurchaseV2", "inAppPurchases", it["id"], suffix))
    ids = [p["id"] for p in have["data"]]
    for rel, typ, rid, suffix in order:
        if rid in taken:
            print(suffix, "already promoted"); continue
        r = asc.call("POST", "/v1/promotedPurchases", {"data": {"type": "promotedPurchases",
                     "attributes": {"visibleForAllUsers": True, "enabled": True},
                     "relationships": {"app": {"data": {"type": "apps", "id": aid}}, rel: {"data": {"type": typ, "id": rid}}}}})
        print(suffix, "promoted" if r else "promote FAILED")
        if r:
            ids.append(r["data"]["id"])
    if ids:
        r = asc.call("PATCH", f"/v1/apps/{aid}/relationships/promotedPurchases", {"data": [{"type": "promotedPurchases", "id": i} for i in ids]})
        print("order set" if r is not None else "order FAILED")


def status():
    aid = asc.find_app()["id"]
    have = asc.call("GET", f"/v1/apps/{aid}/promotedPurchases", params={"limit": 50}) or {"data": []}
    for p in have["data"]:
        print(p["id"], p["attributes"])


if __name__ == "__main__":
    {"images": images, "promote": promote, "status": status}[sys.argv[1] if len(sys.argv) > 1 else "status"]()
