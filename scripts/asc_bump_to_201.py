#!/usr/bin/env python3
"""Rename existing v2.0.0 → v2.0.1, link build 7, set whatsNew."""
import json, time, urllib.request, urllib.error
from pathlib import Path
import jwt

cfg = json.loads(Path("fastlane/api_key.json").read_text())
TOK = jwt.encode(
    {"iss": cfg["issuer_id"], "exp": int(time.time())+1100, "aud": "appstoreconnect-v1"},
    cfg["key"], algorithm="ES256",
    headers={"kid": cfg["key_id"], "typ": "JWT"})
APP_ID = "6762994393"

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

# Find editable version
vers = req("GET", f"/apps/{APP_ID}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION&limit=1")
vid = vers["data"][0]["id"]
cur_str = vers["data"][0]["attributes"]["versionString"]
print(f"Editable version id={vid} current={cur_str}")

# Bump version string
if cur_str != "2.0.1":
    req("PATCH", f"/appStoreVersions/{vid}", {
        "data": {"type":"appStoreVersions","id":vid,"attributes":{"versionString":"2.0.1"}}
    })
    print("Renamed → 2.0.1")

# Find latest VALID build
builds = req("GET", f"/builds?filter[app]={APP_ID}&limit=20")
candidates = sorted(
    [b for b in builds["data"]
     if b["attributes"]["processingState"]=="VALID"
     and not b["attributes"]["expired"]],
    key=lambda b: int(b["attributes"]["version"]),
    reverse=True
)
for b in candidates[:5]:
    a = b["attributes"]
    print(f"  build v{a['version']} state={a['processingState']}")
if candidates:
    bid = candidates[0]["id"]
    print(f"Linking build {candidates[0]['attributes']['version']}")
    req("PATCH", f"/appStoreVersions/{vid}", {
        "data": {"type":"appStoreVersions","id":vid,
                 "relationships":{"build":{"data":{"type":"builds","id":bid}}}}
    })
    print("Linked")
else:
    print("No VALID build yet — wait & re-run")

# Set whatsNew
locs = req("GET", f"/appStoreVersions/{vid}/appStoreVersionLocalizations")
es = next((l for l in locs["data"] if l["attributes"]["locale"] == "es-ES"), None)
if es:
    req("PATCH", f"/appStoreVersionLocalizations/{es['id']}", {
        "data": {"type":"appStoreVersionLocalizations","id":es["id"],
                 "attributes":{"whatsNew":"Mejoras en la integración con Siri y nueva guía en el onboarding para usar comandos de voz. Empieza siempre por \"Clarity\" para activar los atajos al instante."}}
    })
    print("whatsNew set")

print("Done")
