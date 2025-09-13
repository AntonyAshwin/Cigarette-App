//
//  LungColorEngine.swift
//  Cigarette App
//
//  Created by Ashwin, Antony on 13/09/25.
//

import SwiftUI
import Foundation

// 7 discrete tint levels from healthiest (0) to worst (6)
enum LungTintLevel: Int, CaseIterable {
    case level1 = 0, level2, level3, level4, level5, level6, level7

    var color: Color {
        switch self {
        case .level1: return Color(red: 0.13, green: 0.77, blue: 0.37)   // healthy green
        case .level2: return Color(red: 0.52, green: 0.80, blue: 0.09)   // yellow-green
        case .level3: return Color(red: 0.92, green: 0.70, blue: 0.03)   // yellow
        case .level4: return Color(red: 0.96, green: 0.62, blue: 0.04)   // orange
        case .level5: return Color(red: 0.98, green: 0.45, blue: 0.09)   // orange-red
        case .level6: return Color(red: 0.94, green: 0.27, blue: 0.27)   // red
        case .level7: return Color(red: 0.07, green: 0.09, blue: 0.15)   // near-black
        }
    }

    var label: String {
        switch self {
        case .level1: return "Healthy"
        case .level2: return "Improving"
        case .level3: return "Caution"
        case .level4: return "Strained"
        case .level5: return "Poor"
        case .level6: return "Severe"
        case .level7: return "Critical"
        }
    }
}

struct LungColorEngine {
    /// History → 7-level tint with natural recovery.
    /// - Parameters:
    ///   - events: your SmokeEvent list
    ///   - today: anchor date
    ///   - halfLifeDays: recovery speed (smaller = faster recovery)
    ///   - p: dose nonlinearity (>=1). Heavier days hurt more than linear.
    ///   - K: scale factor. Larger = more forgiving overall.
    static func level(
        for events: [SmokeEvent],
        today: Date = Date(),
        halfLifeDays: Double = 10,   // recovery half-life (~10 days)
        p: Double = 1.15,
        K: Double = 50
    ) -> LungTintLevel {
        let cal = Calendar.current
        let today0 = cal.startOfDay(for: today)
        let start  = cal.date(byAdding: .day, value: -89, to: today0)!

        // Build per-day totals in window
        var perDay: [Date: Int] = [:]
        for e in events {
            let d0 = cal.startOfDay(for: e.timestamp)
            if d0 >= start && d0 <= today0 {
                perDay[d0, default: 0] += e.quantity
            }
        }

        // Exponential decay from half-life
        let decay = exp(-log(2.0) / halfLifeDays)

        // Roll oldest → today, accumulating burden
        var B = 0.0
        for i in 0..<90 {
            let day = cal.date(byAdding: .day, value: i - 89, to: today0)!
            let cigs = perDay[day] ?? 0
            let dose = pow(Double(cigs), p)     // heavier days penalized more
            B = B * decay + dose
        }

        // Smooth saturation 0..1 → 0..6 bucket
        let n = 1.0 - exp(-B / K)               // normalized severity
        let bucket = min(6, max(0, Int(round(n * 6.0))))
        return LungTintLevel(rawValue: bucket) ?? .level1
    }
}
