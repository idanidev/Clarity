# Resetear Migración de Categorías

Para forzar que la migración se ejecute de nuevo con el nuevo código mejorado, puedes hacerlo de 2 formas:

## Opción 1: Código Swift (temporal)

Agrega esta línea en `MainTabView.swift` dentro del `.task`:

```swift
.task {
    // TEMPORAL: Borrar clave de migración para forzar re-ejecución
    UserDefaults.standard.removeObject(forKey: "didMigrateCategoriesSlashToDash_v1")
    UserDefaults.standard.removeObject(forKey: "didMigrateCategoriesSlashToDash_v2")

    await userDataManager.loadUserData()
    await LocalRecurringExpenseManager.shared.checkAndCreatePendingExpenses()
    await BackupManager.shared.checkAndCreateAutoBackup()
}
```

Luego:
1. Ejecuta la app una vez
2. Elimina esas líneas
3. Vuelve a compilar

## Opción 2: Lldb en Xcode (más rápido)

1. Abre la app en el simulador
2. En Xcode, presiona el botón de pausa (⏸️)
3. En la consola de debug (abajo), escribe:

```lldb
expr UserDefaults.standard.removeObject(forKey: "didMigrateCategoriesSlashToDash_v1")
expr UserDefaults.standard.removeObject(forKey: "didMigrateCategoriesSlashToDash_v2")
```

4. Presiona el botón de continuar (▶️)
5. Cierra y vuelve a abrir la app

## ¿Qué hará la nueva migración?

- ✅ Busca TODOS los gastos (no solo nombres específicos)
- ✅ Encuentra cualquier categoría que contenga `/`
- ✅ La reemplaza con `-`
- ✅ Maneja espacios correctamente (`" / "` → `-`)
- ✅ Funciona con emojis: `"Coche/Moto 🏍️"` → `"Coche-Moto 🏍️"`

## Logs que verás:

```
🔄 Starting category migration from '/' to '-'...
📦 Checking 147 expenses for '/' in category names...
   ✏️ Updating 'Coche/Moto 🏍️🏎️' → 'Coche-Moto 🏍️🏎️'
   ✏️ Updating 'Vacaciones/Eventos🏖️' → 'Vacaciones-Eventos🏖️'
✅ Category migration completed! Updated 25 expenses
```
