# Premortem — Clarity · 21 de agosto de 2026

## Contexto recopilado

**Qué es:** Clarity, app iOS nativa de control de gastos personales. Gratis, sin anuncios.
Publicada el 24/04/2026, versión 2.0.9 (en revisión en el momento del premortem). Desarrollada
por una sola persona en su tiempo libre; una de sus 4 apps. SwiftUI + Firebase (Auth/Firestore)
+ SwiftData como cache. Diferenciador declarado: registro de gastos por voz y Siri.

**Para quién:** usuarios de habla hispana en España. UI en español (traducción al inglés a
medias: 76 claves frente a 146 usos y 277 literales en español en el código). Moneda fijada a
EUR con locale es_ES.

**Cómo es el éxito (elegido por el desarrollador):** dentro de 6 meses, que exista un grupo real
de usuarios registrando gastos varios días por semana, con retención a 30 días. Que no la
abandonen a las dos semanas. El dinero no es la vara de medir.

**Datos duros:**
- 16 descargas en los últimos 30 días. Es la más descargada de sus 4 apps.
- ⭐5,0 con **un solo voto**. Entre las 4 apps suman 3 votos.
- Competidores en "gastos presupuesto" España: Gestor de gastos (5.001 votos), Monefy (3.680),
  Control de gastos y dinero (2.329).
- Cero medición histórica: Firebase Analytics se acaba de instalar.
- Onboarding: bienvenida → voz/Siri → tutorial → **petición de nómina** → final. Requiere
  **crear cuenta** antes de usar la app.
- Sin canal de contacto con usuarios: ni email, ni comunidad, ni redes.
- Funciones apagadas o a medias: IA deshabilitada, Clarity Pro implementado pero apagado,
  import CSV comentado, traducción parcial, sin multi-moneda.
- Estrategia de crecimiento hasta hoy: solo ASO.

## Los ocho modos de fallo (premortem en bruto)

1. **No hay motor de captación.** 16 descargas/mes; con retención perfecta serían ~100 personas
   en 6 meses. El ASO redistribuye tráfico, no lo crea, y compite contra fichas con miles de votos.
2. **La app pide cuenta y sueldo antes de dar valor.** Registro obligatorio y pantalla de nómina
   en el onboarding.
3. **El diferenciador es socialmente incómodo.** Los gastos se registran en público; hablarle al
   móvil, no.
4. **Círculo cerrado de reseñas.** 1 voto; sin ranking no hay descargas, sin descargas no hay a
   quién pedir reseña.
5. **La muestra es demasiado pequeña para aprender, y no hay a quién preguntar.** D30 sobre
   cohortes de 16 es ruido; sin canal de contacto no hay información cualitativa.
6. **El registro manual pierde contra la conexión bancaria.** El banco y Fintonic ya categorizan
   solos.
7. **Dispersión: construir en vez de distribuir.** Superficie a medio encender mientras los
   usuarios siguen planos.
8. **La retención en apps de gastos muere por diseño.** Coste hoy, beneficio difuso y futuro;
   recordatorio y racha son parches conocidos.

## Análisis profundos

Ocho agentes independientes, en paralelo, uno por modo de fallo. Cada uno produjo la historia del
fallo, el supuesto subyacente y las señales tempranas. El contenido íntegro está volcado en el
informe HTML acompañante, tarjeta por tarjeta.

Convergencias entre análisis independientes (ninguno veía el trabajo de los otros):
- Cuatro de los ocho llegaron por caminos distintos al mismo supuesto: **el problema se trató como
  de producto cuando era de distribución**.
- Tres señalaron que los datos del propio desarrollador contaminarían las métricas.
- Dos señalaron la ausencia de canal de contacto como amplificador de su propio modo de fallo.

## Verificaciones hechas contra el código durante el premortem

| Afirmación de un agente | Resultado |
|---|---|
| Analytics no excluye al usuario desarrollador | **Cierto.** No hay `setUserID` ni exclusión |
| No se mide la racha rota ni la apertura desde recordatorio | **Cierto.** No existen esos eventos |
| No hay email de contacto en la app | **Cierto.** Ni `mailto:` ni dirección de soporte |
| El import de CSV sigue comentado | **Cierto.** `SettingsView.swift:144` |
| El "Saltar" del onboarding lleva a la pantalla de nómina | Señalado por el agente tras leer el código |

## Síntesis

**Fallo más probable:** no hay motor de captación. Con 16 descargas al mes, el criterio de éxito
es inalcanzable por aritmética, trabajes lo que trabajes sobre el producto.

**Fallo más peligroso:** seis meses de decisiones tomadas sobre ruido estadístico, agravado porque
los datos del propio desarrollador dominan las métricas y confirman sus hipótesis.

**Supuesto oculto:** «a la app todavía le falta algo». Clarity no tiene usuarios porque nadie sabe
que existe, no porque le falte una función.

**Plan revisado:**
1. Excluir el `user_id` propio de analytics (una línea, esta semana).
2. Quitar el muro de registro: primer gasto sin cuenta, registro después.
3. Sacar la nómina del onboarding.
4. Poner un email de contacto visible en Ajustes y en la ficha.
5. Un experimento de captación de 4 semanas con métrica declarada (impresiones de ficha).
6. Congelar funciones nuevas hasta pasar de 100 descargas/mes; encender o borrar lo apagado.

**Lista de verificación:**
- [ ] Excluir el `user_id` propio de los agregados
- [ ] Instrumentar el embudo instalación → cuenta → primer gasto
- [ ] Medir la voz por usuario y por franja horaria, no en global
- [ ] Emitir evento de racha rota y de apertura desde recordatorio
- [ ] Elegir el número semanal que duele (descargas nuevas) y mirarlo cada lunes
