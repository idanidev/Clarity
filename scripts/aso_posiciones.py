import json, urllib.parse, urllib.request, time, sys
APP = 6762994393
def buscar(term, pais="es", limit=100):
    u = ("https://itunes.apple.com/search?" + urllib.parse.urlencode(
        {"term": term, "country": pais, "entity": "software", "limit": limit, "lang": "es_es"}))
    req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=25) as r:
            d = json.load(r)
    except Exception as e:
        return None, str(e), []
    apps = [(x["trackId"], x["trackName"]) for x in d.get("results", [])]
    pos = next((i + 1 for i, (tid, _) in enumerate(apps) if tid == APP), None)
    return pos, len(apps), [n for _, n in apps[:3]]

TERMS = ["gastos","control de gastos","gastos diarios","app de gastos","registro de gastos",
 "presupuesto","presupuesto mensual","ahorro","ahorrar dinero","finanzas personales",
 "control financiero","dinero","cuentas","contabilidad personal","gestor de gastos",
 "apuntar gastos","gastos por voz","gastos voz","gastos siri","controlar el dinero",
 "gastos compartidos","deudas","suscripciones","recibos","nomina","hucha","objetivos de ahorro",
 "budget","expense tracker","spending tracker","money manager"]
pais = sys.argv[1] if len(sys.argv) > 1 else "es"
print(f"país: {pais}\n{'término':28} {'posición':>9}  {'resultados':>10}  top 3")
for t in TERMS:
    pos, n, top = buscar(t, pais)
    p = "—" if pos is None else f"#{pos}"
    print(f"{t:28} {p:>9}  {str(n):>10}  {', '.join(x[:22] for x in top)}")
    time.sleep(0.6)
