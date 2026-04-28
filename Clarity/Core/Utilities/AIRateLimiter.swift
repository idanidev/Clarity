//
//  AIRateLimiter.swift
//  Clarity
//
//  Weekly rate limit for AI queries — rolling 7-day window.
//  Persisted in Firestore (source of truth) with UserDefaults cache
//  to prevent bypass via app reinstall or local data clearing.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class AIRateLimiter {
    static let shared = AIRateLimiter()

    static let weeklyLimit = 3
    private let storageKey = "ai.query.timestamps"
    private let firestoreField = "aiQueryTimestamps"
    private let window: TimeInterval = 7 * 24 * 60 * 60

    private var cached: [Date] = []
    private var hasSynced = false

    private init() {
        cached = loadLocal()
    }

    // MARK: - Local cache

    private func loadLocal() -> [Date] {
        let raw = UserDefaults.standard.array(forKey: storageKey) as? [TimeInterval] ?? []
        return raw.map { Date(timeIntervalSince1970: $0) }
    }

    private func saveLocal(_ dates: [Date]) {
        UserDefaults.standard.set(dates.map { $0.timeIntervalSince1970 }, forKey: storageKey)
    }

    private func pruned(_ dates: [Date]) -> [Date] {
        let cutoff = Date().addingTimeInterval(-window)
        return dates.filter { $0 > cutoff }
    }

    // MARK: - Firestore sync

    /// Fetch authoritative timestamps from Firestore, merge with local, persist.
    func sync() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        do {
            let snap = try await Firestore.firestore()
                .collection("users").document(userId).getDocument()
            let remote = (snap.data()?[firestoreField] as? [TimeInterval] ?? [])
                .map { Date(timeIntervalSince1970: $0) }
            // Union of remote + local, then prune.
            let merged = pruned(Array(Set(remote + cached)))
            cached = merged
            saveLocal(merged)
            hasSynced = true
        } catch {
            // Offline — fall back to local cache.
        }
    }

    // MARK: - Public API

    var remaining: Int {
        max(0, Self.weeklyLimit - pruned(cached).count)
    }

    var canQuery: Bool {
        pruned(cached).count < Self.weeklyLimit
    }

    var timeUntilReset: TimeInterval? {
        guard let oldest = pruned(cached).sorted().first else { return nil }
        return max(0, oldest.addingTimeInterval(window).timeIntervalSinceNow)
    }

    /// Record a query locally and in Firestore.
    func record() async {
        let now = Date()
        var current = pruned(cached)
        current.append(now)
        cached = current
        saveLocal(current)

        guard let userId = Auth.auth().currentUser?.uid else { return }
        do {
            try await Firestore.firestore()
                .collection("users").document(userId)
                .updateData([firestoreField: current.map { $0.timeIntervalSince1970 }])
        } catch {
            // Write fails offline — local cache keeps the counter.
            // Next sync() will reconcile.
        }
    }

    func limitReachedMessage() -> String {
        guard let seconds = timeUntilReset else {
            return "Has alcanzado el límite semanal de consultas a la IA."
        }
        let days = Int(ceil(seconds / 86400))
        if days <= 1 {
            let hours = max(1, Int(ceil(seconds / 3600)))
            return "Has alcanzado el límite semanal (\(Self.weeklyLimit) consultas). Vuelve en \(hours) h."
        }
        return "Has alcanzado el límite semanal (\(Self.weeklyLimit) consultas). Vuelve en \(days) días."
    }
}
