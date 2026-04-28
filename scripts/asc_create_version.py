#!/usr/bin/env python3
"""Create new App Store version, copy localization from previous, link latest VALID build."""
import json, time, urllib.request, urllib.error, sys
from pathlib import Path
import jwt

cfg = json.loads(Path("fastlane/api_key.json").read_text())
TOK = jwt.encode(
    {"iss": cfg["issuer_id"], "exp": int(time.time())+1100, "aud": "appstoreconnect-v1"},
    cfg["key"], algorithm="ES256",
    headers={"kid": cfg["key_id"], "typ": "JWT"})
APP_ID = "6762994393"
NEW_VERSION = "2.0.1"
LOCALE = "es-ES"
META = Path("fastlane/metadata/es-ES")

def req(method, path, body=None):
    data = json.dumps(body).encode() if body else None
    r = urllib.request.Request("https://api.appstoreconnect.apple.com/v1"+path, data=data, method=method)
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

# 1) Check if 2.0.1 already exists
vers = req("GET", f"/apps/{APP_ID}/appStoreVersions?limit=10")
existing = next((v for v in vers["data"] if v["attributes"]["versionString"] == NEW_VERSION), None)
if existing:
    version_id = existing["id"]
    print(f"Version {NEW_VERSION} already exists id={version_id} state={existing['attributes']['appStoreState']}")
else:
    print(f"Creating version {NEW_VERSION}")
    r = req("POST", "/appStoreVersions", {
        "data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": NEW_VERSION},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
        }
    })
    version_id = r["data"]["id"]
    print(f"Created id={version_id}")

# 2) Ensure es-ES localization exists
locs = req("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations")
es_loc = next((l for l in locs["data"] if l["attributes"]["locale"] == LOCALE), None)
if not es_loc:
    r = req("POST", "/appStoreVersionLocalizations", {
        "data": {
            "type": "appStoreVersionLocalizations",
            "attributes": {"locale": LOCALE},
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
        }
    })
    es_loc = r["data"]
loc_id = es_loc["id"]
print(f"es-ES loc id={loc_id}")

# 3) PATCH localization with metadata + whatsNew (allowed for non-first releases)
attrs = {}
if v := read("description"): attrs["description"] = v
if v := read("keywords"): attrs["keywords"] = v
if v := read("promotional_text"): attrs["promotionalText"] = v
if v := read("marketing_url"): attrs["marketingUrl"] = v
if v := read("support_url"): attrs["supportUrl"] = v
# whatsNew for 2.0.1
attrs["whatsNew"] = "Mejoras en la integración con Siri y nueva guía en el onboarding para usar comandos de voz. Empieza siempre por \"Clarity\" para activar los atajos al instante."
if attrs:
    req("PATCH", f"/appStoreVersionLocalizations/{loc_id}", {
        "data": {"type": "appStoreVersionLocalizations", "id": loc_id, "attributes": attrs}
    })
    print(f"Patched loc: {list(attrs)}")

# 4) Link latest VALID build
builds = req("GET", f"/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=10")
for b in builds["data"]:
    a = b["attributes"]
    print(f"  build v{a['version']} state={a['processingState']} expired={a['expired']}")
valid = next((b for b in builds["data"]
              if b["attributes"]["processingState"]=="VALID"
              and not b["attributes"]["expired"]
              and b["attributes"]["version"] == "7"), None)
if not valid:
    valid = next((b for b in builds["data"]
                  if b["attributes"]["processingState"]=="VALID"
                  and not b["attributes"]["expired"]), None)
if valid:
    bid = valid["id"]
    print(f"Linking build {valid['attributes']['version']} id={bid}")
    req("PATCH", f"/appStoreVersions/{version_id}", {
        "data": {"type":"appStoreVersions","id":version_id,
                 "relationships":{"build":{"data":{"type":"builds","id":bid}}}}
    })
    print("Linked")
else:
    print("No VALID build yet — re-run later")

print(f"\nDone. Version {NEW_VERSION} ready in ASC web.")
