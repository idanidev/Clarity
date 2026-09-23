# ASO: por qué casi nadie te ve, y qué se cambia (23/09/2026)

## El diagnóstico, con datos

**Impresiones de búsqueda en la App Store:** 400-550 por semana, estables desde
agosto. No es que hayas caído: es que apareces en muy pocas búsquedas.

**Dónde apareces de verdad** (posición en resultados, medido con la API de
búsqueda de Apple el 23/09; script en `scripts/aso_posiciones.py`):

| Término | España | México | Argentina | Colombia |
|---|---|---|---|---|
| gastos por voz | **#1** | #5 | **#1** | **#1** |
| gastos voz | #2 | — | — | — |
| gastos siri | #54 | — | — | — |
| gastos / control de gastos / app de gastos | — | — | — | — |
| presupuesto / presupuesto mensual | — | — | — | — |
| finanzas personales / ahorro / dinero | — | — | — | — |
| registro de gastos / apuntar gastos | — | — | — | — |

«—» es «ni entre los ~90 primeros». Es decir: mandas en «gastos por voz», que
casi nadie busca, y no existes en todo lo que tiene volumen.

**La causa está en el nombre y el subtítulo.** Apple pesa mucho más el título
que las palabras clave, y el título decía «Clarity: Gastos por voz»: la palabra
que sí se busca, «control de gastos», no estaba en ningún sitio fuerte. El
subtítulo («Controla y ahorra sin esfuerzo») gastaba 30 caracteres en un eslogan
sin términos de búsqueda.

## Qué se cambia

| Campo | Antes | Ahora |
|---|---|---|
| Nombre (es) | Clarity: Gastos por voz | **Clarity: Control de gastos** |
| Subtítulo (es) | Controla y ahorra sin esfuerzo | **Apunta por voz y ahorra más** |
| Palabras clave (es) | monefy,fintonic,hucha,deudas,… | presupuesto,finanzas,dinero,cuentas,recurrentes,suscripciones,deudas,nomina,hucha,siri,widget,diario |
| Nombre (en) | Clarity: Expenses by voice | **Clarity: Expense Tracker** |
| Subtítulo (en) | Track your money, effortless | **Say it, it's logged. Save more** |

Criterios:

- **El título se lleva el término con volumen** («control de gastos»), que es
  donde está la gente. «Gastos por voz» se sigue indexando: «gastos» está en el
  título y «voz» en el subtítulo, y Apple combina palabras entre campos.
- **El subtítulo vende y además indexa** («apunta», «voz», «ahorra»).
- **Las palabras clave no repiten** ninguna del título ni del subtítulo: repetir
  no suma y gasta caracteres. Se aprovechan los 100 enteros.
- **Fuera «monefy» y «fintonic»**: son marcas de otros. Apple lo ha dejado pasar
  hasta ahora, pero es motivo de rechazo y ahora mismo un rechazo cuesta una
  ronda de revisión entera. Si algún día quieres arriesgar, vuelven a caber.

## Localización nueva: es-MX

Latinoamérica ya es una de cada cuatro altas (Argentina 22, Colombia 8 en 30
días) y no había ficha propia: se les servía la de España, así que las palabras
clave eran las españolas. `fastlane/metadata/es-MX/` añade 100 caracteres más de
palabras clave para esos países, con su vocabulario: «plata», «sueldo»,
«quincena». El texto largo es el mismo castellano.

## Cómo se mide

1. Antes de publicar, la foto de hoy ya está tomada (la tabla de arriba).
2. `/Users/dani/.rbenv/versions/3.3.0/bin/ruby` no hace falta aquí:
   `python3 scripts/aso_posiciones.py es` (o `mx`, `ar`, `co`) repite la medición.
3. Las impresiones semanales salen de los informes de App Store Connect, ya
   enganchados por API (petición ONGOING). Lo que hay que ver: si las
   impresiones de búsqueda suben de 400-550 a partir de la semana siguiente.
4. Plazo: Apple reindexa en 24-48 h tras publicar, pero la posición tarda una o
   dos semanas en asentarse. No tocar nada mientras tanto o no se sabrá qué fue.

## Lo que NO se ha tocado, y por qué

- **Las capturas.** Se midió: por búsqueda entra en la ficha el 5-8 % tanto
  antes como después de cambiarlas el 14/09. No son la causa de la caída de
  septiembre; esa fue el canal de enlaces compartidos, que pasó de ~40
  instalaciones semanales a 4.
- **El icono.** Puede subir ese 5-8 %, pero va dentro del binario y exige
  versión nueva. Queda para la 2.4.1.
- **La descripción.** No entra en el índice de búsqueda de Apple (a diferencia
  de Google Play). Sirve para convencer a quien ya está en la ficha.
