---
description: Scaffolding de una nueva feature siguiendo la arquitectura de Clarity
argument-hint: [nombre-feature]
---

Vamos a crear el scaffolding para la feature: **$ARGUMENTS**

La arquitectura de Clarity sigue Clean Architecture con MVVM:

!`ls Clarity/Features/`

Crea la estructura completa:

```
Clarity/Features/$ARGUMENTS/
├── Views/
│   └── $ARGUMENTSView.swift
├── ViewModels/
│   └── $ARGUMENTSViewModel.swift
└── Services/ (solo si necesita lógica de negocio propia)
    └── $ARGUMENTSService.swift
```

Reglas:
- ViewModel usa @Observable (no ObservableObject)
- ViewModel es @MainActor
- View es struct, sin lógica de negocio
- Inyectar dependencias via DependencyContainer
- Localización en español primario
- Seguir el Design System de DesignSystem.swift
