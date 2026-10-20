"""Push Store/l10n_iap.json to App Store Connect: subscription group + plan localizations and the 99-cent items.

    python Store/l10n_push.py

The Big Hand ("pro") is left alone on purpose: it is approved and live, and stays exactly as it is.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402
import club  # noqa: E402
import iap2  # noqa: E402

data = json.loads((Path(__file__).resolve().parent / "l10n_iap.json").read_text(encoding="utf-8"))
gid = club.group()["id"]
club.group_locs(gid, {loc: (v["group"], None) for loc, v in data.items()})
print("group localizations done")
for suffix, *_ in club.PLANS:
    s = club.find(gid, club.BASE + suffix)
    club.sub_locs(s["id"], {loc: tuple(v[suffix]) for loc, v in data.items()})
    print(suffix, "localizations done")
for suffix, *_ in iap2.PRODUCTS:
    it = iap2.find(iap2.BASE + suffix)
    if not it:
        continue
    have = asc.call("GET", f"/v2/inAppPurchases/{it['id']}/inAppPurchaseLocalizations", params={"limit": 50}) or {"data": []}
    by = {l["attributes"]["locale"]: l for l in have["data"]}
    for loc, v in data.items():
        name, desc = v[suffix]
        if loc in by:
            asc.call("PATCH", f"/v1/inAppPurchaseLocalizations/{by[loc]['id']}", {"data": {"type": "inAppPurchaseLocalizations", "id": by[loc]["id"], "attributes": {"name": name, "description": desc}}})
        else:
            r = asc.call("POST", "/v1/inAppPurchaseLocalizations", {"data": {"type": "inAppPurchaseLocalizations", "attributes": {"locale": loc, "name": name, "description": desc},
                         "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": it["id"]}}}}})
            if not r:
                print(" ", suffix, loc, "FAILED")
    print(suffix, "localizations done")
