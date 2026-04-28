#!/usr/bin/env python3
"""Check ASC publish readiness."""
import json, time, urllib.request, urllib.error
from pathlib import Path
import jwt

cfg = json.loads(Path("fastlane/api_key.json").read_text())
TOK = jwt.encode(
    {"iss": cfg["issuer_id"], "exp": int(time.time())+1100, "aud": "appstoreconnect-v1"},
    cfg["key"], algorithm="ES256",
    headers={"kid": cfg["key_id"], "typ": "JWT"})
APP_ID = "6762994393"

def req(p):
    r = urllib.request.Request("https://api.appstoreconnect.apple.com/v1"+p)
    r.add_header("Authorization", f"Bearer {TOK}")
    return json.loads(urllib.request.urlopen(r).read())

vers = req(f"/apps/{APP_ID}/appStoreVersions?limit=3")
for v in vers["data"]:
    a = v["attributes"]
    print(f"v{a['versionString']} state={a['appStoreState']} platform={a['platform']} created={a['createdDate']}")
    vid = v["id"]
    # build
    try:
        b = req(f"/appStoreVersions/{vid}/build")
        if b.get("data"):
            ba = b["data"]["attributes"]
            print(f"  build={ba.get('version')} processingState={ba.get('processingState')} expired={ba.get('expired')}")
        else:
            print("  build=NONE")
    except Exception as e:
        print(f"  build err: {e}")
    # localizations
    locs = req(f"/appStoreVersions/{vid}/appStoreVersionLocalizations")
    for l in locs["data"]:
        la = l["attributes"]
        flags = []
        for k in ["description","keywords","promotionalText","supportUrl","marketingUrl","whatsNew"]:
            v = la.get(k)
            flags.append(f"{k}={'Y' if v else '-'}")
        print(f"  {la['locale']}: {' '.join(flags)}")
    # review detail
    try:
        rd = req(f"/appStoreVersions/{vid}/appStoreReviewDetail")
        if rd.get("data"):
            ra = rd["data"]["attributes"]
            print(f"  review: phone={ra.get('contactPhone')} email={ra.get('contactEmail')} demo={ra.get('demoAccountName')}")
        else:
            print("  review: MISSING")
    except urllib.error.HTTPError as e:
        print(f"  review: {e.code}")

# AppInfo + categories
infos = req(f"/apps/{APP_ID}/appInfos")
for ai in infos["data"]:
    aa = ai["attributes"]
    print(f"AppInfo state={aa.get('appStoreState')} ageRating={aa.get('appStoreAgeRating')}")
    cats = req(f"/appInfos/{ai['id']}?include=primaryCategory,secondaryCategory")
    inc = {i['id']: i for i in cats.get('included', [])}
    rels = cats['data']['relationships']
    pc = rels.get('primaryCategory', {}).get('data')
    sc = rels.get('secondaryCategory', {}).get('data')
    print(f"  primary={inc.get(pc['id'],{}).get('id') if pc else None} secondary={inc.get(sc['id'],{}).get('id') if sc else None}")
    # localizations
    ail = req(f"/appInfos/{ai['id']}/appInfoLocalizations")
    for l in ail["data"]:
        la = l["attributes"]
        print(f"  {la['locale']}: name={'Y' if la.get('name') else '-'} subtitle={'Y' if la.get('subtitle') else '-'} privacy={'Y' if la.get('privacyPolicyUrl') else '-'}")

# Pricing
try:
    p = req(f"/apps/{APP_ID}/appPriceSchedule")
    print(f"price: {p['data']['attributes']}")
except Exception as e:
    print(f"price err: {e}")
