---
name: ios-build-verify
description: Verifica que el código compila correctamente después de hacer cambios.
  Usar SIEMPRE después de editar archivos Swift antes de dar la tarea por terminada.
allowed-tools: Bash, Read
---

Verifica que la app compila sin errores tras los cambios realizados.

1. Ejecuta el build:
```bash
xcodebuild -project Clarity.xcodeproj -scheme Clarity -sdk iphonesimulator -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | grep -v "warning:" | head -30
```

2. Si hay errores:
   - Lee el archivo afectado
   - Identifica la causa del error
   - Aplica el fix mínimo necesario
   - Vuelve a verificar

3. Solo reportar al usuario cuando BUILD SUCCEEDED o si hay errores que requieren su input.

No reportar warnings, solo errores reales que impidan compilar.
