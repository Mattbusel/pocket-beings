"""In-App Events for the monthly Seasons: card + details art per event, localized, deep-linked to the Season window.

    python Store/events.py <media dir>          create/update every event below, upload art, print states

Media dir holds <key>-card.png (1920x1080) and <key>-details.png (1080x1920) from Store/art/event.mjs.
Idempotent: reuses an event with the same reference name.
"""
import sys
import time
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

media = Path(sys.argv[1])
EVENTS = [
    {
        "key": "election", "ref": "Pocket Beings Season: Election Season (Nov 2026)", "badge": "NEW_SEASON",
        "schedule": {"publishStart": "2026-10-25T16:00:00Z", "eventStart": "2026-11-01T05:00:00Z", "eventEnd": "2026-12-01T04:59:00Z"},
        "copy": {
            "en-US": ("Election Season", "Every seat is up for grabs, every vote for sale",
                      "A new 10-tier Season track, three weekly challenges and a turkey face to keep. Crown, jail and bribe your way."),
            "ja": ("選挙シーズン", "すべての席が争奪戦、票はすべて売り物", "新しい10段階のシーズン、毎週3つのチャレンジ、記念の顔。王冠も牢屋も思いのまま。"),
            "ko": ("선거 시즌", "모든 자리가 걸렸고 모든 표는 팝니다", "새로운 10단계 시즌, 매주 3개의 도전, 간직할 시즌 얼굴. 왕관도 감옥도 마음대로."),
            "zh-Hans": ("选举季", "每个席位都在争夺,每张选票都能买", "全新 10 级赛季、每周三项挑战和可收藏的赛季头像。加冕、关押、贿赂随你。"),
            "de-DE": ("Wahlsaison", "Jeder Sitz ist zu haben, jede Stimme käuflich", "Eine neue Saison mit 10 Stufen, drei Wochenaufgaben und einem Truthahn-Gesicht zum Behalten."),
            "fr-FR": ("Saison des élections", "Tous les sièges à prendre, tous les votes à vendre", "Une nouvelle Saison à 10 paliers, trois défis par semaine et un visage de dinde à garder."),
            "es-MX": ("Temporada electoral", "Cada puesto en juego, cada voto a la venta", "Una nueva Temporada de 10 niveles, tres retos semanales y una cara de pavo para quedártela."),
        },
    },
    {
        "key": "heist", "ref": "Pocket Beings Season: Holiday Heist (Dec 2026)", "badge": "NEW_SEASON",
        "schedule": {"publishStart": "2026-11-17T17:00:00Z", "eventStart": "2026-12-01T05:00:00Z", "eventEnd": "2027-01-01T04:59:00Z"},
        "copy": {
            "en-US": ("Holiday Heist", "Somebody is stealing the presents",
                      "December's Season: a new 10-tier track, three weekly challenges and a Santa face to keep. Everybody suspects Snik."),
            "ja": ("ホリデー大強盗", "誰かがプレゼントを盗んでいる", "12月のシーズン:新しい10段階のトラック、毎週3つのチャレンジ、サンタの顔。みんなスニクを疑っています。"),
            "ko": ("홀리데이 하이스트", "누군가 선물을 훔치고 있어요", "12월 시즌: 새로운 10단계 트랙, 매주 3개의 도전, 산타 얼굴. 모두 스닉을 의심해요."),
            "zh-Hans": ("节日大劫案", "有人在偷礼物", "十二月赛季:全新 10 级进度、每周三项挑战和圣诞老人头像。大家都怀疑 Snik。"),
            "de-DE": ("Festtags-Coup", "Jemand stiehlt die Geschenke", "Die Dezember-Saison: 10 neue Stufen, drei Wochenaufgaben und ein Weihnachtsmann-Gesicht. Alle verdächtigen Snik."),
            "fr-FR": ("Le casse des fêtes", "Quelqu'un vole les cadeaux", "La Saison de décembre : 10 paliers, trois défis par semaine et un visage de père Noël. Tout le monde soupçonne Snik."),
            "es-MX": ("El gran robo navideño", "Alguien se está robando los regalos", "La Temporada de diciembre: 10 niveles, tres retos semanales y una cara de Santa. Todos sospechan de Snik."),
        },
    },
]


def upload(lid, kind, f):
    data = f.read_bytes()
    made = asc.call("POST", "/v1/appEventScreenshots", {"data": {"type": "appEventScreenshots",
                    "attributes": {"fileName": f.name, "fileSize": len(data), "appEventAssetType": kind},
                    "relationships": {"appEventLocalization": {"data": {"type": "appEventLocalizations", "id": lid}}}}})
    if not made:
        print("   reserve failed", kind); return
    made = made["data"]
    for op in made["attributes"]["uploadOperations"]:
        h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
        requests.request(op["method"], op["url"], headers=h, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
    asc.call("PATCH", f"/v1/appEventScreenshots/{made['id']}", {"data": {"type": "appEventScreenshots", "id": made["id"], "attributes": {"uploaded": True}}})


def main():
    aid = asc.find_app()["id"]
    terr = [t["id"] for t in asc.call("GET", "/v1/territories", params={"limit": 200})["data"]]
    have = {e["attributes"]["referenceName"]: e for e in asc.call("GET", f"/v1/apps/{aid}/appEvents", params={"limit": 50})["data"]}
    for e in EVENTS:
        for loc, (n, s, l) in e["copy"].items():
            assert len(n) <= 30 and len(s) <= 50 and len(l) <= 120 and "—" not in n + s + l, (e["key"], loc, len(n), len(s), len(l))
        attrs = {"referenceName": e["ref"], "badge": e["badge"], "primaryLocale": "en-US", "priority": "NORMAL",
                 "purpose": "APPROPRIATE_FOR_ALL_USERS", "deepLink": "pocketbeings://season",
                 "territorySchedules": [dict(territories=terr, **e["schedule"])]}
        if e["ref"] in have:
            ev = have[e["ref"]]
            asc.call("PATCH", f"/v1/appEvents/{ev['id']}", {"data": {"type": "appEvents", "id": ev["id"], "attributes": {k: v for k, v in attrs.items() if k not in ("referenceName", "primaryLocale")}}})
        else:
            made = asc.call("POST", "/v1/appEvents", {"data": {"type": "appEvents", "attributes": attrs,
                            "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}})
            if not made:
                print(e["key"], "create FAILED"); continue
            ev = made["data"]
        print(e["key"], "event", ev["id"])
        locs = {x["attributes"]["locale"]: x for x in asc.call("GET", f"/v1/appEvents/{ev['id']}/localizations")["data"]}
        for loc, (n, s, l) in e["copy"].items():
            a = {"name": n, "shortDescription": s, "longDescription": l}
            if loc in locs:
                asc.call("PATCH", f"/v1/appEventLocalizations/{locs[loc]['id']}", {"data": {"type": "appEventLocalizations", "id": locs[loc]["id"], "attributes": a}})
            else:
                made = asc.call("POST", "/v1/appEventLocalizations", {"data": {"type": "appEventLocalizations", "attributes": dict(locale=loc, **a),
                                "relationships": {"appEvent": {"data": {"type": "appEvents", "id": ev["id"]}}}}})
                if not made:
                    print("  loc", loc, "FAILED"); continue
                locs[loc] = made["data"]
            lid = locs[loc]["id"]
            got = {x["attributes"]["appEventAssetType"] for x in asc.call("GET", f"/v1/appEventLocalizations/{lid}/appEventScreenshots")["data"]}
            for kind, f in (("EVENT_CARD", media / f"{e['key']}-card.png"), ("EVENT_DETAILS_PAGE", media / f"{e['key']}-details.png")):
                if kind not in got:
                    upload(lid, kind, f)
        time.sleep(3)
        ev = asc.call("GET", f"/v1/appEvents/{ev['id']}")["data"]
        print(" ", e["key"], "state:", ev["attributes"]["eventState"])
        print(f"  add to the review submission with: reviewSubmissionItems appEvent {ev['id']}")


if __name__ == "__main__":
    main()
