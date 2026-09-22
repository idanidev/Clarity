// SwiftDataService.swift
// Manager for SwiftData Container and Context

import Foundation
import OSLog
import SwiftData

@MainActor
final class SwiftDataService {
    static let shared = SwiftDataService()

    // `static`: se usa dentro del `init`, antes de que exista `self`.
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "SwiftDataService")

    let container: ModelContainer
    
    var context: ModelContext {
        container.mainContext
    }
    
    private init() {
        let schema = Schema([
            ExpenseModel.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // Cada paso de esta escalera tiraba la caché sin decir nada: si un día
        // el almacén no abre (una migración que falla, disco lleno), lo único
        // que se veía era una app lenta que lo vuelve a bajar todo. La política
        // no cambia —la caché se regenera desde Firestore—, pero deja rastro.
        do {
            self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            Self.excluirDeLaCopiaDeiCloud(modelConfiguration.url)
        } catch {
            Self.logger.error("El almacén local no abre; se borra y se recrea: \(String(describing: error), privacy: .public)")
            // If the persistent store is corrupted, try deleting and recreating
            try? FileManager.default.removeItem(at: modelConfiguration.url)
            do {
                self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                Self.excluirDeLaCopiaDeiCloud(modelConfiguration.url)
            } catch {
                Self.logger.error("El almacén local tampoco abre recién creado; caché solo en memoria esta sesión: \(String(describing: error), privacy: .public)")
                // Last resort: in-memory only so the app doesn't crash
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                do {
                    self.container = try ModelContainer(for: schema, configurations: [memoryConfig])
                } catch {
                    Self.logger.fault("Ni el almacén en memoria abre: \(String(describing: error), privacy: .public)")
                    // Último recurso: container vacío para que la app no crashee
                    // Esto nunca debería ocurrir — un container en memoria siempre funciona
                    self.container = try! ModelContainer(for: schema)
                }
            }
        }
    }

    /// Saca el almacén de la copia de iCloud y de iTunes: es una caché de lo
    /// que hay en Firestore, 100 % regenerable, y crece con el historial. Con
    /// sus dos ficheros de SQLite, que son archivos aparte. Se repite en cada
    /// arranque porque la marca se pierde si el fichero se recrea.
    private static func excluirDeLaCopiaDeiCloud(_ almacen: URL) {
        var valores = URLResourceValues()
        valores.isExcludedFromBackup = true
        for sufijo in ["", "-wal", "-shm"] {
            var url = URL(fileURLWithPath: almacen.path + sufijo)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                try url.setResourceValues(valores)
            } catch {
                logger.warning("No se pudo excluir de la copia de iCloud \(url.lastPathComponent, privacy: .public): \(error.localizedDescription)")
            }
        }
    }
}
