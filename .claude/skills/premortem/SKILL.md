---
name: premortem
description: "Ejecuta un premortem sobre cualquier plan, lanzamiento, producto, contratación, estrategia o decisión. Asume que ya falló 6 meses después y trabaja hacia atrás para encontrar todos los motivos. Produce un plan revisado con los puntos ciegos expuestos. DISPARADORES OBLIGATORIOS: 'premortem esto', 'premortem mi', 'ejecuta un premortem', 'qué podría matar esto', 'prueba de estrés este plan', 'qué me estoy perdiendo aquí', 'encuentra los puntos ciegos'. DISPARADORES FUERTES: 'qué podría salir mal', 'me estoy perdiendo algo', 'hazle agujeros a esto', 'dónde va a romperse esto', 'abogado del diablo'. NO disparar en solicitudes simples de retroalimentación, preguntas factuales o solicitudes al Consejo LLM. SÍ disparar cuando alguien tiene un plan o compromiso donde el coste de equivocarse es alto."
---

# Premortem

Un premortem es lo contrario de un postmortem. En lugar de averiguar qué salió mal después de que algo falla, imaginas que ya falló y averiguas por qué antes de empezar.

El método proviene del psicólogo Gary Klein. Lo publicó en Harvard Business Review. Daniel Kahneman (el psicólogo ganador del Premio Nobel detrás de "Pensar rápido, pensar despacio") lo llamó su técnica más valiosa para la toma de decisiones. Google, Goldman Sachs y Procter & Gamble lo usan antes de grandes decisiones.

La idea clave: cuando preguntas a la gente "¿qué podría salir mal?" dan respuestas cautelosas y ambiguas. Cuando dices "esto ya falló, dime por qué", el cerebro cambia al modo narrativo y genera razones mucho más específicas, creativas y honestas. Investigadores de Wharton y Cornell llamaron a esto "retrospectiva prospectiva" y descubrieron que aumenta significativamente la capacidad de identificar causas de resultados futuros.

Por qué importa esto para las decisiones asistidas por IA: Claude tiende a respuestas amables y optimistas. Si preguntas "¿es este un buen plan?" encontrará razones para decir que sí. El premortem rompe este patrón al forzar el encuadre en "esto está muerto, explica cómo murió". Claude deja de buscar razones por las que tu plan funcionará y empieza a explicar cómo se desmoronó.

---

## cuándo ejecutar un premortem

Buenos objetivos para un premortem:
- Un producto o funcionalidad que estás a punto de construir
- Un plan de lanzamiento con dinero o reputación en juego
- Un cambio de precio o modelo de negocio
- Una contratación que estás a punto de hacer
- Un pivote de estrategia o posicionamiento
- Una alianza o acuerdo que estás evaluando
- Cualquier compromiso donde el coste de equivocarse es alto

Malos objetivos para un premortem:
- Ideas vagas sin ningún plan concreto todavía (ayúdalos a planificar primero, luego haz el premortem)
- Preguntas con una sola respuesta correcta (simplemente respóndelas)
- Solicitudes de retroalimentación creativa sobre un borrador (eso es edición, no un premortem)
- Decisiones que ya están tomadas e irreversibles (un premortem solo es útil cuando aún puedes cambiar de rumbo)

---

## recopilación de contexto (el mínimo necesario)

Un premortem es tan bueno como el contexto sobre el que se ejecuta. La información vaga produce escenarios de fallo vagos que no ayudan a nadie. Antes de ejecutar el premortem, necesitas alcanzar un umbral mínimo de contexto.

### paso 1: buscar contexto existente

Antes de preguntar nada al usuario, busca contexto que ya esté disponible:

**A. La conversación actual.** El usuario puede haber estado discutiendo un plan, un lanzamiento, un producto o una decisión antes en esta sesión. Lee la conversación y extrae lo que sea relevante.

**B. El espacio de trabajo.** Escanea rápidamente en busca de archivos que puedan contener contexto relevante:
- `CLAUDE.md` o `claude.md` (contexto empresarial, preferencias, restricciones)
- Cualquier carpeta `memory/` (perfiles de audiencia, detalles del negocio, decisiones pasadas)
- Archivos que el usuario referenciara o adjuntara explícitamente
- Cualquier archivo de proyecto, briefs o planes relacionados con lo que se está sometiendo al premortem

Usa `Glob` y llamadas rápidas a `Read`. No dediques más de 30 segundos a esto. Buscas los archivos clave que anclarán los escenarios de fallo en la realidad.

### paso 2: evaluar la suficiencia del contexto

Después de escanear, comprueba si tienes suficiente para ejecutar un premortem útil. Necesitas tres cosas:

1. **¿Qué es?** — Una comprensión clara de lo que se está sometiendo al premortem (un producto, un lanzamiento, una contratación, un cambio de precio, una estrategia). Debes ser capaz de describírselo al usuario en una frase.

2. **¿Para quién es / a quién afecta?** — La audiencia, el cliente, el equipo, las partes interesadas. Los escenarios de fallo dependen en gran medida de quién está involucrado.

3. **¿Cómo es el éxito?** — ¿Qué resultado espera el usuario? El fallo se define invirtiendo el éxito. Si no sabes qué significa el éxito, no puedes definir qué significa el fracaso.

### paso 3: completar las lagunas de forma conversacional

Si tienes los tres, procede inmediatamente al premortem. No hagas preguntas innecesarias.

Si te falta uno o más, pregunta primero por la pieza más importante que falta. Una pregunta a la vez. Evalúa después de cada respuesta si ahora tienes suficiente. Sigue preguntando hasta alcanzar el umbral, pero nunca preguntes más de lo necesario.

Ejemplos de preguntas de contexto enfocadas:
- "¿Qué es exactamente lo que estás a punto de lanzar/construir/decidir?" (si no sabes qué es)
- "¿Para quién es esto?" (si conoces el plan pero no la audiencia)
- "¿Cómo sería una victoria para esto?" (si conoces el plan y la audiencia pero no los criterios de éxito)

El objetivo es alcanzar el mínimo lo más rápido posible sin hacer que el usuario sienta que está rellenando un formulario. Conversacional, no interrogativo. Si puedes inferir una respuesta del contexto, hazlo en lugar de preguntar.

---

## cómo funciona una sesión de premortem

### paso 1: establecer el encuadre

Después de recopilar suficiente contexto, establece el encuadre del premortem explícitamente. Algo como:

"Bien, tengo suficiente contexto. Vamos a ejecutar el premortem. La premisa es: han pasado 6 meses. [El plan/lanzamiento/decisión] ha fallado. Está hecho. Miramos hacia atrás intentando entender qué salió mal."

Este encuadre importa. Cambia el modo de "evalúa este plan" (que desencadena respuestas complacientes) a "explica por qué murió esto" (que desencadena una identificación honesta y específica de los fallos).

### paso 2: generar razones de fallo (premortem en bruto)

Ejecuta el premortem en bruto como un análisis único y completo. Sin categorías prefijadas, sin lentes, sin restricciones. Solo el método Klein básico:

"Este plan ha fallado 6 meses después. Genera cada razón genuina por la que podría haber muerto. Sé exhaustivo. Sé específico. Fundamenta cada razón en los detalles reales del plan. No rellenes con razones débiles y no pares antes de tiempo si hay más."

El resultado debe ser una lista completa de razones de fallo, cada una expresada en 1-2 frases. Sé honesto y exhaustivo. Algunos planes pueden tener 4 modos de fallo genuinos. Otros pueden tener 9. El número debe ser el que sea real para este plan específico.

Cada razón de fallo debe ser:
- Específica de este plan (no un consejo genérico que aplique a cualquier cosa)
- Fundamentada en detalles reales que el usuario proporcionó
- Una amenaza genuina (no un inconveniente menor o un caso extremadamente improbable)

### paso 3: agentes de análisis profundo (uno por razón de fallo, todos en paralelo)

Toma cada razón de fallo del paso 2 y lanza un sub-agente por razón, todos en paralelo. Cada agente toma su razón de fallo asignada y la analiza en profundidad de forma independiente.

**Plantilla de prompt para sub-agente:**

```
Eres un investigador en un análisis de premortem. Se te ha asignado una razón de fallo específica para analizar en profundidad.

El plan:
---
[contexto completo: qué es, para quién es, cómo es el éxito, más contexto relevante del espacio de trabajo]
---

ENCUADRE DEL PREMORTEM: Han pasado 6 meses. Este plan ha fallado.

TU RAZÓN DE FALLO ASIGNADA: [la razón de fallo específica del paso 2]

Tu trabajo es profundizar en este fallo. Escribe la historia de cómo se desarrolló realmente. Sé específico. Usa detalles del plan. Hazlo sentir real, como un estudio de caso de algo que realmente ocurrió.

Tu resultado debe incluir:

1. LA HISTORIA DEL FALLO: Una narrativa de 2-3 párrafos de cómo se desarrolló este fallo específico. Usa detalles del plan. Nombra momentos específicos donde las cosas salieron mal y por qué.

2. EL SUPUESTO SUBYACENTE: La única cosa que el usuario daba por sentada y que hizo posible este fallo. Exprésalo en una frase.

3. SEÑALES DE ADVERTENCIA TEMPRANAS: 1-2 señales concretas y observables que el usuario podría vigilar y que indicarían que este modo de fallo está empezando a desarrollarse. Deben ser cosas que se puedan ver o medir realmente, no sensaciones vagas.

Mantén la respuesta total por debajo de 300 palabras. Sé directo. No lo atenúes. No lo suavices.
```

### paso 4: síntesis

Después de que todos los agentes completen, lee cada análisis profundo y produce la síntesis:

**INFORME DE PREMORTEM**

1. **El Fallo Más Probable** — ¿Qué escenario de fallo es más probable dado lo que sabes sobre el plan? ¿Por qué? Este es en el que el usuario debe enfocarse primero.

2. **El Fallo Más Peligroso** — ¿Qué escenario de fallo causaría más daño si ocurriera, aunque sea menos probable? Este es el que vale la pena asegurar.

3. **El Supuesto Oculto** — De todos los análisis de fallo, ¿cuál es el supuesto más importante que el usuario está haciendo y que probablemente no ha cuestionado? Aquí es donde a menudo vive el valor real del premortem: lo que es tan obvio para el usuario que olvidó que era un supuesto.

4. **El Plan Revisado** — Basándose en los escenarios de fallo, ¿qué cambios específicos harían el plan más resiliente? Sé concreto. No digas "considera tu precio". Di "prueba el precio en $X con 20 personas antes de comprometerte públicamente". Cada revisión debe corresponderse directamente con un escenario de fallo específico.

5. **La Lista de Verificación Pre-Lanzamiento** — 3-5 cosas específicas que el usuario debe verificar, probar o implementar antes de ejecutar. Cada una debe prevenir o detectar uno de los modos de fallo identificados.

### paso 5: generar el informe de premortem

Genera un informe HTML visual y guárdalo en el espacio de trabajo del usuario.

**Archivo:** `premortem-report-[timestamp].html`

El informe debe ser un único archivo HTML autocontenido con CSS en línea. Principios de diseño:
- Fondo oscuro (#0a0e1a o similar), tipografía limpia, fácil de escanear
- La sección de síntesis (fallo más probable, fallo más peligroso, supuesto oculto, plan revisado, lista de verificación) debe mostrarse de forma prominente al principio ya que es lo que la mayoría de las personas leerá primero
- Una tarjeta visual por razón de fallo que muestre el análisis profundo. Cada tarjeta debe mostrar la razón de fallo como encabezado, la historia del fallo, el supuesto subyacente y las señales de advertencia tempranas. Usa colores de acento distintos para cada tarjeta para que sean visualmente escaneables.
- Un indicador visual claro de gravedad/probabilidad para cada modo de fallo
- El visual rotativo: muestra el número de agentes que se ejecutaron y sus hallazgos como una cuadrícula o diseño de tarjetas, para que el usuario pueda ver el alcance completo del premortem de un vistazo
- Pie de página con marca de tiempo y qué fue sometido al premortem

Abre el archivo HTML después de generarlo.

### paso 6: guardar la transcripción

Guarda la transcripción completa del premortem como `premortem-transcript-[timestamp].md` en la misma ubicación. Esto incluye:
- El contexto que se recopiló (qué, quién, criterios de éxito)
- Las razones de fallo del premortem en bruto
- Todos los análisis profundos de los agentes
- La síntesis completa

---

## formato de salida

Cada sesión de premortem produce dos archivos:

```
premortem-report-[timestamp].html    # informe visual para escanear
premortem-transcript-[timestamp].md  # transcripción completa como referencia
```

El usuario ve primero el informe HTML. La transcripción está disponible si quiere profundizar en el razonamiento detrás de cada escenario de fallo.

También proporciona un resumen conciso en el chat: el fallo más probable, el supuesto oculto y la única revisión más importante del plan. Máximo tres frases. El informe tiene todos los detalles.

---

## ejemplo: premortem de un lanzamiento de producto

**Usuario:** "premortem esto: estoy a punto de lanzar un taller en vivo de $297 sobre cómo usar Claude Cowork para equipos de marketing. 50 plazas. Dirigido a directores de marketing en empresas con 10-50 empleados."

**El premortem en bruto identifica 6 razones de fallo:**
1. Los directores de marketing en empresas de este tamaño necesitan aprobación para gastar $297 en desarrollo profesional, añadiendo fricción que no has tenido en cuenta
2. "Claude Cowork para marketing" es un pitch centrado en una herramienta en un mercado donde la mayoría de los directores todavía están decidiendo si la IA es relevante para ellos
3. La audiencia que realmente compra podría ser solopreneurs, no directores de equipo, creando un desajuste entre el contenido y los asistentes
4. Construir un taller para equipos de marketing requiere entornos de demostración con datos de marketing realistas y configuraciones multiusuario, lo que lleva 5 semanas de preparación, no las 2 que has presupuestado
5. Si el 60% de los asistentes son solopreneurs, tus reseñas y casos de estudio no resonarán con la audiencia de directores de marketing que necesitas para cohortes futuras
6. A $297 con 50 plazas, el ingreso máximo es $14.850, lo que puede no justificar el tiempo de preparación frente a otras oportunidades de ingresos

**6 agentes profundizan en cada razón de forma independiente, produciendo historias de fallo, supuestos subyacentes y señales de advertencia tempranas.**

**Síntesis:** El fallo más probable es el desajuste de audiencia: estás apuntando a personas que necesitan aprobación para gastar $297, lo que añade fricción que no has tenido en cuenta. El fallo más peligroso: atraer solopreneurs en lugar de directores de equipo significa que tus casos de estudio y testimonios no resonarán con el comprador objetivo real para cohortes futuras, agravando el problema con el tiempo. Supuesto oculto: asumes que "directores de marketing en empresas de 10-50 personas" es una audiencia alcanzable, pero estas personas no se identifican de esa manera y no están en los mismos lugares. Plan revisado: ejecuta una sesión piloto de $47 para 20 personas primero. Usa eso para identificar si tus compradores reales son directores de equipo o solopreneurs, y construye el taller completo para quien realmente aparezca.

---

## notas importantes

- **Siempre lanza todos los agentes de fallo en paralelo.** El lanzamiento secuencial desperdicia tiempo y permite que las respuestas anteriores influyan en las posteriores.
- **Siempre establece el encuadre del premortem explícitamente.** "Esto ya ha fallado" es el mecanismo psicológico que hace que esto funcione. Sin él, el análisis vuelve a ser una evaluación de riesgos cortés en lugar de una identificación honesta de fallos.
- **Sé exhaustivo pero no rellenes.** Encuentra cada razón de fallo genuina. No pares en 3 si hay 7. Pero no fuerces 7 si solo hay 3. El número debe ser el que sea real para este plan específico.
- **La síntesis es el producto.** La mayoría de los usuarios leerán la síntesis y hojearán las tarjetas de fallo individuales. Haz la síntesis específica y accionable.
- **No suavices.** El objetivo de un premortem es decirle al usuario cosas que no quiere escuchar antes de que lo haga la realidad. Si un plan tiene problemas serios, dilo directamente.
- **El plan revisado debe ser concreto.** No digas "considera probar tu precio". Di "ejecuta un piloto de $47 con 20 personas antes de comprometerte con el taller completo de $297". Cada revisión debe ser algo que el usuario pueda hacer realmente esta semana.
- **Respeta el umbral mínimo de contexto.** Ejecutar un premortem con contexto insuficiente produce fallos genéricos que desperdician el tiempo del usuario. Es mejor hacer una pregunta más que producir un mal premortem.
- **Esto no es el Consejo LLM.** El consejo da múltiples perspectivas sobre una decisión ahora mismo. El premortem envía a Claude al futuro donde la decisión ya falló y trabaja hacia atrás para explicar por qué. Mecanismo psicológico diferente, resultado diferente. Si el usuario parece querer múltiples perspectivas en lugar de un análisis de fallos, sugiere el consejo en su lugar.
