# Clarity iOS Native

Aplicación nativa iOS para Clarity - Gestor de Gastos Personal con IA.

## Requisitos

- Xcode 15+
- iOS 16.0+
- Swift 5.9+

## Configuración

### 1. Firebase

1. Descarga `GoogleService-Info.plist` desde Firebase Console
2. Añádelo a la carpeta `Clarity/Resources/`

### 2. Dependencias

El proyecto usa Swift Package Manager. Las dependencias se resolverán automáticamente al abrir en Xcode.

**Dependencias:**

- Firebase iOS SDK (Auth, Firestore, Functions, Messaging)
- KeychainAccess

## Estructura del Proyecto

```
Clarity/
├── App/                    # Entry point y navegación principal
├── Core/                   # Extensiones y utilidades
├── Data/
│   ├── Models/            # Modelos de datos (Codable)
│   ├── Repositories/      # Acceso a Firestore
│   └── Services/          # Servicios externos
├── Features/
│   ├── Auth/              # Login/Registro
│   ├── Dashboard/         # Lista de gastos
│   ├── AddExpense/        # Formulario de nuevo gasto
│   ├── Charts/            # Gráficos
│   ├── Budgets/           # Presupuestos
│   ├── AIAssistant/       # Chat con IA
│   └── Settings/          # Configuración
├── UI/
│   ├── Components/        # Componentes reutilizables
│   ├── Theme/             # Colores, tipografía, espaciado
│   └── Modifiers/         # View modifiers
└── Resources/             # Assets, localización
```

## Características

- ✅ Autenticación (Email/Password)
- ✅ CRUD de gastos con Firestore
- ✅ Categorización con subcategorías
- ✅ Gráficos con Swift Charts
- ✅ Presupuestos mensuales
- ✅ Asistente IA (Cloud Functions)
- ✅ Tema claro/oscuro automático
- ✅ Diseño adaptativo iPhone/iPad

## Para Agregar

- [ ] Google Sign-In
- [ ] Apple Sign-In
- [ ] Input por voz (Speech Framework)
- [ ] Push Notifications
- [ ] Widget iOS
- [ ] Apple Watch app

## Conexión con App Web

Esta app nativa se conecta al **mismo backend Firebase** que la app web/Capacitor existente, permitiendo a los usuarios usar ambas versiones con los mismos datos.

**Firebase Project:** `clarity-gastos`
