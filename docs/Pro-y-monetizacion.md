# Clarity Pro y monetización — ideas pendientes de decidir

Notas de septiembre de 2026. Nada de esto está decidido: Pro se queda apagado
(`ProConfig.paywallEnabled = false`) hasta saber qué va en él.

## Lo que ya existe en el código

- Suscripción con tres productos en `SubscriptionManager.swift`:
  `com.idanidev.clarity.pro.monthly`, `.pro.yearly`, `.pro.lifetime`.
  Falta comprobar que existen y están aprobados en App Store Connect.
- Pantalla de pago (`ProPaywallView`) con restaurar compra, y `ProBadge`.
- `ProLimits`: límite de 30 gastos por voz al mes para quien no es Pro, con el
  cambio de mes probado en tests.
- Todo apagado: con el interruptor en `false` nadie está limitado.

## Antes de nada: retención

Datos del 31/08/2026 (issue #57): el 54 % nunca registra un gasto y la
retención en la semana 2 es del 0 %. Cobrar sin arreglar eso rinde poco. Mirar
los datos actuales de Firebase antes de encender Pro.

## Planes (opciones)

| Opción | Precios orientativos | Notas |
|---|---|---|
| Anual + de por vida | ~17,99 €/año, ~39,99 € | Recomendada. Prueba gratis de 7 días. A quien controla gastos le cuesta una cuota mensual. |
| Mensual + anual + de por vida | ~2,49 €/mes, ~17,99 €/año, ~39,99 € | Son los tres productos que ya hay. |
| Solo de por vida | ~29,99 € | Lo más simple; sin ingresos recurrentes. |

Apple se queda el 15 % con el Small Business Program.

## Qué iría gratis y qué en Pro (opciones)

**Siempre gratis**, porque sin esto la gente se va: registrar gastos a mano,
categorías, la Home básica.

- **Propuesta amplia.** Gratis: gastos a mano, categorías, Home básica,
  recurrentes y una meta. Pro: voz ilimitada, Home editable, metas
  ilimitadas, iconos alternativos y temas, exportar y copias, informes
  avanzados («tu normal», comparativas).
- **Pro ligero.** Casi todo gratis; Pro solo quita el límite de voz y añade la
  Home editable, iconos y temas.
- Si vuelve la IA, tiene que ir en Pro: cada consulta cuesta dinero.

## Otras vías

- **Propinas** («Invítame a un café»): tres compras sueltas de 1,99 / 4,99 /
  9,99 € en Ajustes, junto a «Escríbeme». Poco trabajo y no molesta. Encaja con
  el tono de «Lo lee una persona: yo».
- **Clarity en pareja**: presupuestos y gastos compartidos entre dos cuentas.
  La base existe (modo regalo, deudores). Es lo que más se paga en estas apps,
  pero es el proyecto más grande.
- **Anuncios con recompensa**, como experimento cuando haya más usuarios:
  «mira un anuncio y desbloquea 10 dictados más este mes».

## Lo que no haría

- **Anuncios normales, por ahora.** Con el volumen actual darían decenas de
  euros al mes como mucho; obligan a dos ventanas más al primer arranque
  (consentimiento RGPD y aviso de rastreo de Apple) justo donde ya se pierde a
  la mitad; cambian la etiqueta de privacidad a «rastrea»; las redes suelen
  poner préstamos rápidos y tarjetas de crédito; y hacen la app más pesada.
  Si algún día se ponen: un banner pequeño al final de la lista de gastos,
  nunca a pantalla completa, y que Pro lo quite.
- Afiliación con bancos ni vender datos.

## Antes de encender Pro

- Productos creados y aprobados en App Store Connect.
- Pantalla de pago conforme a Apple: precio claro, condiciones, privacidad.
- Probar el cambio de mes del límite de voz en un dispositivo.
- Actualizar la etiqueta de privacidad si cambia algo.
