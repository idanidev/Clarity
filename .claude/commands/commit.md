---
description: Crea un commit inteligente con los cambios actuales
argument-hint: [mensaje opcional]
---

## Estado actual

!`git status --short`

## Cambios

!`git diff --stat HEAD`

Analiza los cambios y crea un commit con este formato:
- Prefijo: feat/fix/refactor/perf/ui/docs según el tipo
- Mensaje en español, máximo 72 caracteres
- Si se pasa $ARGUMENTS úsalo como mensaje base

Ejecuta: git add -A && git commit con el mensaje generado.
No uses --no-verify. Si hay errores en el hook, corrígelos primero.
