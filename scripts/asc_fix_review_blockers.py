#!/usr/bin/env python3
"""Set copyright on version + contentRightsDeclaration on AppInfo."""
import json, time, urllib.request, urllib.error
from pathlib import Path
import jwt

cfg = json.loads(Path("fastlane/api_key.json").read_text())
TOK = jwt.encode(
    {"iss": cfg["issuer_id"], "exp": int(time.time())+1100, "aud": "appstoreconnect-v1"},
    cfg["key"], algorithm="ES256",
    headers={"kid": cfg["key_id"], "typ": "JWT"})
APP_ID = "6762994393"
COPYRIGHT = "2026 Daniel Benito Diaz"

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

# 1) Copyright on App (not on version)
req("PATCH", f"/apps/{APP_ID}", {
    "data": {"type":"apps","id":APP_ID,
             "attributes":{}}
})  # confirm app patchable
# Actually copyright lives on appStoreVersion per ASC v3
vers = req("GET", f"/apps/{APP_ID}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION&limit=1")
vid = vers["data"][0]["id"]
print(f"Version {vers['data'][0]['attributes']['versionString']} id={vid}")
req("PATCH", f"/appStoreVersions/{vid}", {
    "data": {"type":"appStoreVersions","id":vid,
             "attributes":{"copyright": COPYRIGHT}}
})
print(f"copyright set: {COPYRIGHT}")

# 2) contentRightsDeclaration on AppInfo
infos = req("GET", f"/apps/{APP_ID}/appInfos")
editable = next((i for i in infos["data"]
                 if i["attributes"].get("appStoreState") in ("PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW")
                 or i["attributes"].get("state") == "PREPARE_FOR_SUBMISSION"), infos["data"][0])
aid = editable["id"]
print(f"AppInfo id={aid}")
# DOES_NOT_USE_THIRD_PARTY_CONTENT or USES_THIRD_PARTY_CONTENT
req("PATCH", f"/appInfos/{aid}", {
    "data": {"type":"appInfos","id":aid,
             "attributes":{"contentRightsDeclaration":"DOES_NOT_USE_THIRD_PARTY_CONTENT"}}
})
print("contentRightsDeclaration: DOES_NOT_USE_THIRD_PARTY_CONTENT")

print("Done")
