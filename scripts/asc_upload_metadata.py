#!/usr/bin/env python3
"""Upload App Store textos directly via ASC API, bypassing fastlane review_detail bug."""
import json, time, urllib.request, urllib.error, os, sys
from pathlib import Path
import jwt  # PyJWT

KEY_PATH = Path("fastlane/api_key.json")
META = Path("fastlane/metadata/es-ES")
APP_ID = "6762994393"
LOCALE = "es-ES"

cfg = json.loads(KEY_PATH.read_text())
KEY_ID = cfg["key_id"]
ISSUER_ID = cfg["issuer_id"]
PRIVATE_KEY = cfg["key"]

def token():
    return jwt.encode(
        {"iss": ISSUER_ID, "exp": int(time.time()) + 1100, "aud": "appstoreconnect-v1"},
        PRIVATE_KEY,
        algorithm="ES256",
        headers={"kid": KEY_ID, "typ": "JWT"},
    )

TOK = token()
BASE = "https://api.appstoreconnect.apple.com/v1"

def req(method, path, body=None):
    url = BASE + path if path.startswith("/") else path
    data = json.dumps(body).encode() if body else None
    r = urllib.request.Request(url, data=data, method=method)
    r.add_header("Authorization", f"Bearer {TOK}")
    r.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(r) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        print(f"ERR {method} {path}: {e.code} {e.read().decode()}")
        raise

def read(name):
    p = META / f"{name}.txt"
    return p.read_text().strip() if p.exists() else None

# 1) Find latest editable AppStoreVersion
vers = req("GET", f"/apps/{APP_ID}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION&limit=1")
if not vers["data"]:
    print("No editable version found")
    sys.exit(1)
version_id = vers["data"][0]["id"]
version_str = vers["data"][0]["attributes"]["versionString"]
print(f"Version {version_str} id={version_id}")

# 2) Get version localizations
locs = req("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations")
es_loc = next((l for l in locs["data"] if l["attributes"]["locale"] == LOCALE), None)
if not es_loc:
    print(f"Creating {LOCALE} localization")
    r = req("POST", "/appStoreVersionLocalizations", {
        "data": {
            "type": "appStoreVersionLocalizations",
            "attributes": {"locale": LOCALE},
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
        }
    })
    es_loc = r["data"]
loc_id = es_loc["id"]
print(f"Version loc es-ES id={loc_id}")

# 3) PATCH version localization (description, keywords, promo, marketing, support, whatsNew)
attrs = {}
if v := read("description"): attrs["description"] = v
if v := read("keywords"): attrs["keywords"] = v
if v := read("promotional_text"): attrs["promotionalText"] = v
if v := read("marketing_url"): attrs["marketingUrl"] = v
if v := read("support_url"): attrs["supportUrl"] = v
# whatsNew skipped — first-ever release cannot have release notes
if attrs:
    req("PATCH", f"/appStoreVersionLocalizations/{loc_id}", {
        "data": {"type": "appStoreVersionLocalizations", "id": loc_id, "attributes": attrs}
    })
    print(f"Patched version loc: {list(attrs)}")

# 4) Find AppInfo (editable one)
infos = req("GET", f"/apps/{APP_ID}/appInfos")
editable = next((i for i in infos["data"]
                 if i["attributes"].get("appStoreState") in ("PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW")
                 or i["attributes"].get("state") == "PREPARE_FOR_SUBMISSION"), infos["data"][0])
appinfo_id = editable["id"]
print(f"AppInfo id={appinfo_id}")

# 5) AppInfoLocalizations for name, subtitle, privacyPolicyUrl
ail = req("GET", f"/appInfos/{appinfo_id}/appInfoLocalizations")
es_ail = next((l for l in ail["data"] if l["attributes"]["locale"] == LOCALE), None)
if not es_ail:
    r = req("POST", "/appInfoLocalizations", {
        "data": {
            "type": "appInfoLocalizations",
            "attributes": {"locale": LOCALE},
            "relationships": {"appInfo": {"data": {"type": "appInfos", "id": appinfo_id}}},
        }
    })
    es_ail = r["data"]
ail_id = es_ail["id"]

ai_attrs = {}
if v := read("name"): ai_attrs["name"] = v
if v := read("subtitle"): ai_attrs["subtitle"] = v
if v := read("privacy_url"): ai_attrs["privacyPolicyUrl"] = v
if ai_attrs:
    req("PATCH", f"/appInfoLocalizations/{ail_id}", {
        "data": {"type": "appInfoLocalizations", "id": ail_id, "attributes": ai_attrs}
    })
    print(f"Patched app info loc: {list(ai_attrs)}")

print("Done")
