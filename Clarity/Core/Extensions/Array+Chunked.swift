//
//  Array+Chunked.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-27.
//

import Foundation

extension Array {
    // `nonisolated`: función pura sin estado — se llama desde actores no-main
    // (p.ej. el actor UserDataService al trocear batch writes). Con aislamiento
    // @MainActor por defecto, sin esto daría warning de Swift 6.
    nonisolated func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
