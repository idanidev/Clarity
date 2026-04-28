#!/usr/bin/env python3
"""Create App Store version 2.0.2."""
import json, time, urllib.request, urllib.error
from pathlib import Path
import jwt

cfg = json.loads(Path("fastlane/api_key.json").read_text())
TOK = jwt.encode(
    {"iss": cfg["issuer_id"], "exp": int(time.time())+1100, "aud": "appstoreconnect-v1"},
    cfg["key"], algorithm="ES256",
    headers={"kid": cfg["key_id"], "typ": "JWT"})
APP_ID = "6762994393"
NEW_VERSION = "2.0.2"
LOCALE = "es-ES"
META = Path("fastlane/metadata/es-ES")

WHATS_NEW = (
    "Correcciones críticas:\n"
    "- Inicio de sesión con Google funcional.\n"
    "- Al cerrar sesión se limpian los datos del usuario anterior.\n"
    "- El botón \"Empezar\" del onboarding ya no se queda bloqueado.\n"
    "- Rediseño completo de la pantalla de inicio de sesión.\n"
    "- Editar Hucha/Escudo no muestra ya el selector de tipo.\n"
    "- Categorías y subcategorías nuevas se pueden crear sin salir del flujo."
)

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

vers = req("GET", f"/apps/{APP_ID}/appStoreVersions?limit=10")
existing = next((v for v in vers["data"] if v["attributes"]["versionString"] == NEW_VERSION), None)
if existing:
    version_id = existing["id"]
    print(f"Version {NEW_VERSION} already exists id={version_id} state={existing['attributes']['appStoreState']}")
else:
    r = req("POST", "/appStoreVersions", {
        "data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": NEW_VERSION},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
        }
    })
    version_id = r["data"]["id"]
    print(f"Created v{NEW_VERSION} id={version_id}")

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

attrs = {"whatsNew": WHATS_NEW}
if v := read("description"): attrs["description"] = v
if v := read("keywords"): attrs["keywords"] = v
if v := read("promotional_text"): attrs["promotionalText"] = v
if v := read("marketing_url"): attrs["marketingUrl"] = v
if v := read("support_url"): attrs["supportUrl"] = v
req("PATCH", f"/appStoreVersionLocalizations/{loc_id}", {
    "data": {"type": "appStoreVersionLocalizations", "id": loc_id, "attributes": attrs}
})
print(f"Patched loc: {list(attrs)}")
print(f"\nDone. v{NEW_VERSION} created in ASC. Build 16 will auto-link once uploaded.")
