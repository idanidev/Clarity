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
  versión nueva. Aparcado (23/09): dos rondas de propuestas generadas no
  convencieron; se hará con referencias o con un diseñador, sin prisa, porque
  no es lo que frena el crecimiento.
- **La descripción.** No entra en el índice de búsqueda de Apple (a diferencia
  de Google Play). Sirve para convencer a quien ya está en la ficha.

## Segunda vuelta (26/10/2026): subtítulos que indexan y palabras clave sin promesas

El detalle y la checklist están en el issue #75. Lo que se ha cambiado en
`fastlane/metadata/`:

| Campo | Antes | Ahora |
|---|---|---|
| Subtítulo (en) | Say it, it's logged. Save more | **Budget Planner & Spending Log** |
| Palabras clave (en) | budget,spending,money,voice,siri,subscriptions,debts,savings,widget,finance,payday,receipts | money,finance,personal,saving,bills,subscriptions,income,payday,debts,goals,manager,widget,monthly |
| Subtítulo (es-ES) | Apunta por voz y ahorra más | **Finanzas personales y ahorro** |
| Palabras clave (es-ES) | presupuesto,finanzas,dinero,cuentas,recurrentes,suscripciones,deudas,nomina,hucha,siri,widget,diario | presupuesto,dinero,ingresos,nomina,hucha,suscripciones,deudas,mensual,apuntar,siri,widget,metas,voz |
| Subtítulo (es-MX) | Registra por voz y ahorra | **Finanzas personales y ahorro** |
| Palabras clave (es-MX) | presupuesto,finanzas,dinero,plata,sueldo,quincena,deudas,suscripciones,ahorro,siri,widget,mensual | presupuesto,dinero,plata,sueldo,quincena,ingresos,deudas,suscripciones,mensual,metas,widget,siri,voz |

Criterios:

- **El subtítulo deja de ser eslogan.** En español lleva «finanzas
  personales», la búsqueda genérica de la categoría, y «ahorro» (se busca el
  sustantivo). «Presupuesto» no va en el subtítulo: en español también es
  «cotización» y arrastra búsquedas de apps de presupuestos y facturas para
  autónomos; se queda en palabras clave, donde esa mezcla no penaliza. «Voz»
  pasa también a palabras clave. En inglés, «budget planner» y «spending log».
  Pendiente de contrastar con la popularidad que dé la herramienta de ASO.
- **Nada que la app no haga.** Fuera «receipts» (no hay escaneo de tickets) y
  fuera de la ficha en inglés «voice», «dictate» y «speech»: el reconocedor va
  fijo en `es-ES` (`SpeechRecognitionManager`), el parser solo entiende euros y
  números en castellano y las frases de Siri son en español. «Voice» vuelve al
  título en inglés (`Clarity: Voice Expense Tracker`, 30) cuando la voz y la
  interfaz funcionen en inglés.
- **Fuera términos con intención equivocada:** «facturas» (apps de facturación),
  «cartera»/«wallet» (billeteras y marca ajena), «hogar» (no hay gasto
  compartido del hogar).
- **Las palabras clave siguen sin repetir** nada del nombre ni del subtítulo.
  es-MX va lleno (100); es-ES queda en 99 y en-US en 98.

El nombre no cambia: «Clarity: Control de gastos» y «Clarity: Expense Tracker».
Nombre, subtítulo y palabras clave solo se pueden editar al enviar una versión
nueva, así que esto sale con la siguiente.

Las valoraciones se piden también, desde esta versión, al cerrar la enhorabuena
de hucha completada, al cerrar la de mes dentro del presupuesto y al marcar una
deuda como cobrada (`ReviewRequestManager`, mismas reglas de frecuencia).
