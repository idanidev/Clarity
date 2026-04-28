#!/usr/bin/env python3
import json, time, urllib.request
from pathlib import Path
import jwt

cfg = json.loads(Path("fastlane/api_key.json").read_text())
TOK = jwt.encode(
    {"iss": cfg["issuer_id"], "exp": int(time.time())+1100, "aud": "appstoreconnect-v1"},
    cfg["key"], algorithm="ES256",
    headers={"kid": cfg["key_id"], "typ": "JWT"})
APP_ID = "6762994393"
VERSION_ID = "f523f2f9-6570-4633-a33a-4318292b78a2"

def req(method, path, body=None):
    data = json.dumps(body).encode() if body else None
    r = urllib.request.Request("https://api.appstoreconnect.apple.com/v1"+path, data=data, method=method)
    r.add_header("Authorization", f"Bearer {TOK}")
    r.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(r) as resp:
        raw = resp.read()
        return json.loads(raw) if raw else {}

# find latest VALID build
builds = req("GET", f"/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=5")
for b in builds["data"]:
    a = b["attributes"]
    print(f"build {a['version']} state={a['processingState']} expired={a['expired']} valid={a.get('valid')}")
valid = next((b for b in builds["data"] if b["attributes"]["processingState"]=="VALID" and not b["attributes"]["expired"]), None)
if not valid:
    print("No VALID build")
    exit(1)
bid = valid["id"]
print(f"Linking build {bid}")
req("PATCH", f"/appStoreVersions/{VERSION_ID}", {
    "data": {"type":"appStoreVersions","id":VERSION_ID,
             "relationships":{"build":{"data":{"type":"builds","id":bid}}}}
})
print("Linked")
