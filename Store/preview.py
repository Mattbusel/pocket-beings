"""Upload the App Store app preview video for a version (6.9" iPhone set, en-US by default).

    python Store/preview.py <version> <mp4> [--locale en-US] [--frame 00:00:04:00]

Replaces whatever preview is in the set. The mp4 must already be 886x1920, 15-30 s, H.264 with an audio track.
"""
import hashlib
import sys
import time
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402


def main(version, path, locale="en-US", frame="00:00:04:00"):
    app = asc.find_app()
    v = asc.call("GET", f"/v1/apps/{app['id']}/appStoreVersions", params={"filter[versionString]": version})["data"][0]
    loc = next(l for l in asc.call("GET", f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations", params={"limit": 50})["data"]
               if l["attributes"]["locale"] == locale)
    sets = asc.call("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appPreviewSets")["data"]
    pset = next((s for s in sets if s["attributes"]["previewType"] == "IPHONE_67"), None)
    if not pset:
        pset = asc.call("POST", "/v1/appPreviewSets", {"data": {"type": "appPreviewSets", "attributes": {"previewType": "IPHONE_67"},
                        "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}}}}})["data"]
    for old in asc.call("GET", f"/v1/appPreviewSets/{pset['id']}/appPreviews")["data"]:
        asc.call("DELETE", f"/v1/appPreviews/{old['id']}")
    data = Path(path).read_bytes()
    made = asc.call("POST", "/v1/appPreviews", {"data": {"type": "appPreviews",
                    "attributes": {"fileName": Path(path).name, "fileSize": len(data), "mimeType": "video/mp4", "previewFrameTimeCode": frame},
                    "relationships": {"appPreviewSet": {"data": {"type": "appPreviewSets", "id": pset["id"]}}}}})["data"]
    for op in made["attributes"]["uploadOperations"]:
        h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
        requests.request(op["method"], op["url"], headers=h, data=data[op["offset"]: op["offset"] + op["length"]], timeout=300).raise_for_status()
    asc.call("PATCH", f"/v1/appPreviews/{made['id']}", {"data": {"type": "appPreviews", "id": made["id"],
             "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    for _ in range(30):
        st = asc.call("GET", f"/v1/appPreviews/{made['id']}")["data"]["attributes"].get("assetDeliveryState", {})
        print("preview", st.get("state"), st.get("errors") or "")
        if st.get("state") in ("COMPLETE", "FAILED"):
            break
        time.sleep(10)


if __name__ == "__main__":
    a = sys.argv
    main(a[1], a[2], a[a.index("--locale") + 1] if "--locale" in a else "en-US", a[a.index("--frame") + 1] if "--frame" in a else "00:00:04:00")
