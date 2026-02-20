# ⚠️ Firebase Cloud Functions - DEPRECATED

Este directorio contiene las antiguas Cloud Functions de Firebase que ya **NO están en uso**.

## 🔴 Estado actual: DEPRECATED

**Fecha:** 2 de febrero de 2025

Las Cloud Functions se desactivaron porque:
1. Firebase alcanzó el límite del plan gratuito
2. No tiene sentido pagar mensualmente por algo que puede ejecutarse localmente
3. La app funciona igual o mejor sin ellas

## ✅ Nueva solución (iOS nativo)

Toda la lógica se migró a:
```
/Clarity/Features/RecurringExpenses/Managers/LocalRecurringExpenseManager.swift
```

### Funcionalidad:
- ✅ Crea gastos recurrentes automáticamente al abrir la app
- ✅ Recupera gastos perdidos del mes actual
- ✅ Soporta: Mensual, Trimestral, Semestral, Anual
- ✅ Sin costos, sin servidor, sin complicaciones

## 📦 Archivos movidos a backup

Los archivos originales están en `.backup/`:
- `index.js` - Cloud Functions principales
- `get-userid.js` - Utilidades
- `test-recurring.js` - Tests
- `trigger-manual.js` - Triggers manuales

## 🗑️ ¿Puedo eliminar este directorio?

**Sí**, puedes eliminarlo completamente. La app ya no lo usa.

Si quieres mantenerlo como referencia histórica, déjalo. No afecta en nada.

## 📖 Más información

Lee `DEPRECATED.md` para detalles completos sobre la migración.

---

## 📚 Documentación original (histórica)

<details>
<summary>Ver documentación original de las Cloud Functions</summary>

### Setup original

#### Prerequisites
- Node.js 18 or higher
- Firebase CLI (`npm install -g firebase-tools`)
- Firebase project configured

#### Installation

1. Navigate to the functions directory:
   ```bash
   cd functions
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

### Functions originales

#### `processRecurringExpenses`
**Type:** Scheduled (PubSub)
**Schedule:** Daily at 9:00 AM
**Purpose:** Automatically processes all active recurring expenses

#### Frequency Logic original

- **Monthly**: Charges every month on `dayOfMonth`
- **Quarterly**: Charges every 3 months starting from `billingMonth`
- **Semestral**: Charges every 6 months starting from `billingMonth`
- **Yearly**: Charges once per year in `billingMonth`

</details>
