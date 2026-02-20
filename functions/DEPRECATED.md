# ⚠️ DEPRECATED - Cloud Functions

**Fecha de deprecación:** 2 de febrero de 2025

## ¿Por qué se deprecó?

Firebase Cloud Functions alcanzó el límite del plan gratuito. Para evitar costos recurrentes, toda la lógica de gastos recurrentes se migró al cliente iOS.

## Nueva implementación

La funcionalidad de gastos recurrentes ahora se ejecuta **localmente en el dispositivo iOS**:

📍 **Ubicación:** `/Clarity/Features/RecurringExpenses/Managers/LocalRecurringExpenseManager.swift`

### Ventajas de la nueva implementación:

✅ **Gratis** - No hay costos de servidor
✅ **Privado** - Todo se procesa en el dispositivo
✅ **Rápido** - No requiere conexión a internet para verificar
✅ **Simple** - Menos infraestructura que mantener

### ¿Cómo funciona ahora?

1. **Al abrir la app**: `checkAndCreatePendingExpenses()` verifica si hay gastos del día actual
2. **Al abrir Gastos Recurrentes**: `recoverMissedExpenses()` recupera gastos perdidos del mes

### Protecciones:

- ✅ Solo se ejecuta 1 vez al día
- ✅ Verifica que no existan duplicados antes de crear
- ✅ Soporta: Mensual, Trimestral, Semestral, Anual
- ✅ Desactiva automáticamente gastos expirados

## Archivos deprecados

Los siguientes archivos ya **NO se usan** y pueden eliminarse:

- `index.js` - Funciones principales (createRecurringExpenses, checkMissedRecurringExpenses)
- `get-userid.js` - Utilidad para obtener user ID
- `test-recurring.js` - Tests de las Cloud Functions
- `trigger-manual.js` - Trigger manual para testing
- `node_modules/` - Dependencias de Node.js
- `package.json` / `package-lock.json` - Configuración NPM

## ¿Necesitas volver a Cloud Functions?

Si en el futuro necesitas Cloud Functions (por ejemplo, para procesamiento en background garantizado), toda la lógica está en este directorio como referencia.

**Comandos útiles que ya no necesitas:**
```bash
# Ya no necesarios
cd functions && npm install
cd functions && npm run serve
cd functions && npm run deploy
```

---

**Nota:** Este directorio se mantiene solo como referencia histórica. Puedes eliminarlo completamente si lo deseas.
