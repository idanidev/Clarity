---
name: swift-code-review
description: Revisa código Swift/SwiftUI para detectar bugs, problemas de concurrencia,
  y violaciones de arquitectura. Usar cuando se pide revisar código antes de commitear
  o cuando hay comportamientos inesperados.
allowed-tools: Read, Grep, Glob
---

Revisa el código Swift indicado con foco en:

1. **Concurrencia Swift 6**: @MainActor, @Sendable, async/await correcto
2. **Memory leaks**: ciclos de retención en closures y delegates
3. **Arquitectura**: separación de capas, no mezclar responsabilidades
4. **Lógica de negocio**: cálculos de fechas en local time, no UTC
5. **Firebase**: queries eficientes, no descargar toda la colección

Formato de respuesta:
- ✅ Lo que está bien
- ⚠️ Advertencias menores
- ❌ Problemas que hay que corregir (con fix)

@../../rules/swift-conventions.md
@../../rules/architecture.md
