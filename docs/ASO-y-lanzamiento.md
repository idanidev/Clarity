# Clarity — ASO, monetización y lo que queda por hacer a mano

Resultado de los issues [#39](https://github.com/idanidev/Clarity/issues/39) y
[#40](https://github.com/idanidev/Clarity/issues/40). Todo lo que se podía
resolver con código ya está en el repo; aquí queda lo que solo puedes hacer tú
desde App Store Connect o desde Xcode.

## 1. Ficha de la App Store

Los textos ya están escritos en `fastlane/metadata/`. `es-ES` actualizado y
`en-US` creado desde cero (antes no existía).

| Campo | Valor nuevo |
|---|---|
| Subtítulo ES | `Apunta por voz con IA y ahorra` (30/30 caracteres) |
| Keywords ES | `monefy,fintonic,wallet,hucha,deudas,suscripcion,recurrente,nomina,siri,dinero,widget,finanzas,cuenta` (100/100) |
| Subtítulo EN | `Log by voice with AI, save` |
| Descripción | Arranca con el gancho de voz, no con "app simple y bonita" |

Criterio de las keywords: no repiten ninguna palabra del nombre
(`Clarity: Gastos y Presupuesto`) ni del subtítulo, porque App Store ya indexa
esas. Por eso desaparecen `voz`, `ahorrar` y `presupuesto` del campo: ya están
cubiertas por título y subtítulo, y el hueco se aprovecha para competidores
(`monefy`, `fintonic`, `wallet`) y términos nuevos (`dinero`, `cuenta`).

**Subir con:** `bundle exec fastlane deliver --skip_binary_upload` o a mano.

## 2. Capturas

`scripts/generate_mockups.py` regenerado. La primera captura ya es la del gancho
de voz + Siri, que es lo que te separa de Monefy y compañía.

- 01 — "Di lo que gastas y queda apuntado" / Por voz o con Siri, en 5 segundos
- 02 — "Mira en qué se te va el mes" / Pincha una categoría y ve el detalle
- 03 — "Ahorra con objetivos claros"
- 04 — "Tus gastos fijos, en piloto automático"

**Ojo con la 04:** la captura de origen (`4_ai.png`) es de la pantalla de la
asesora IA, que **está deshabilitada en la app**. El texto ya no habla de IA,
pero la imagen sigue siendo esa pantalla. Antes de subir, sustituye
`marketing/screenshots/input/4_ai.png` por una captura de Gastos Recurrentes y
vuelve a lanzar el script. Enseñar una función que la app no tiene es
incumplimiento de la guideline 2.3.

Por el mismo motivo se ha quitado de la descripción la sección
`ASISTENTE IA "CLARA"`.

Para llegar a 8-10 capturas (el máximo, y sube conversión) faltan capturas
nuevas del simulador: modo regalo, detalle de categoría en tabla, widget,
recordatorios y racha. El generador ya las monta en cuanto dejes los PNG en
`marketing/screenshots/input/`.

Falta también el **vídeo de preview**: hay que grabarlo, no se puede generar.

## 3. Reseñas

`ReviewRequestManager` ya pide la reseña con `AppStore.requestReview`:

- a partir de la 3ª sesión,
- después de guardar un gasto (momento de éxito, nunca al abrir),
- una sola vez por versión y como mucho 3 al año.

No hay nada que configurar. Se dispara solo.

## 4. Clarity Pro — lo que falta

El código está completo (`Clarity/Features/Subscription/`) pero **el paywall
llega apagado**: `ProConfig.paywallEnabled` lee
`UserDefaults` → `pro.paywallEnabled`, que por defecto es `false`. Mientras siga
así, `isPro` devuelve `true` para todo el mundo y la app se comporta igual que
hoy. Nadie pierde funciones por sorpresa.

Para encenderlo:

1. Crea los productos en App Store Connect con estos IDs exactos:
   - `com.idanidev.clarity.pro.monthly`
   - `com.idanidev.clarity.pro.yearly`
   - `com.idanidev.clarity.pro.lifetime`
2. Añade la capability **In-App Purchase** al target en Xcode.
3. Actualiza la descripción: ahora dice "Sin suscripción obligatoria" y "Sin
   pantallas de upgrade molestas", y dejaría de ser cierto.
4. Pon el flag a `true` (`ProConfig.setPaywallEnabled(true)`).

Límites del plan gratuito, todos en `ProLimits`: 30 gastos por voz al mes.
Al agotarse se abre el paywall con el motivo `voiceLimit`. La exportación a CSV
también queda detrás de Pro.

Para probar sin App Store Connect: `Clarity.storekit` está en la raíz con los
tres productos y una semana de prueba en el anual. Actívalo en Xcode →
Edit Scheme → Run → Options → StoreKit Configuration.

## 5. Analytics

`AnalyticsService` emite los eventos (`onboarding_completed`, `expense_added`
con `method`, `paywall_shown`, `purchase_completed`, `review_prompted`,
`debt_settled`) y calcula en local la retención D1/D7/D30 y la métrica norte
(`isHabitualUser` = 3+ días con gasto en los últimos 7).

Por defecto solo escribe en la consola unificada de Apple: **no sale ni un dato
del dispositivo**. Para mandarlos a Firebase:

1. Xcode → Package Dependencies → `firebase-ios-sdk` → añade el producto
   **FirebaseAnalytics** al target Clarity.
2. Ya está: `FirebaseAnalyticsSink` está detrás de
   `#if canImport(FirebaseAnalytics)` y se engancha solo al arrancar.

**Antes de subir una build con Analytics enlazado** hay que declarar la recogida
de datos en la ficha de privacidad de App Store Connect y añadir las entradas
correspondientes a `PrivacyInfo.xcprivacy`. Esa declaración la tienes que firmar
tú; por eso el enlace del paquete se ha dejado sin hacer.

## 6. Distribución (nada de esto es código)

- Vídeo de "20 euros en gasolina" → gasto categorizado solo. Es el gancho más
  visual que tienes y sirve igual para TikTok, Reels y Shorts.
- Reddit: r/espana, r/FinanzasPersonales.
