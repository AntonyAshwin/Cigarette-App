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
    // MARK: - Core severity (0...1) from history with decay
    static func severity(
        from events: [SmokeEvent],
        today: Date = Date(),
        lookbackDays: Int = 90,
        halfLifeDays: Double = 10,   // recovery half-life (~10 days)
        p: Double = 1.15,            // non-linear daily dose
        K: Double = 50               // saturation scale
    ) -> Double {
        let cal = Calendar.current
        let today0 = cal.startOfDay(for: today)
        let start  = cal.date(byAdding: .day, value: -(lookbackDays - 1), to: today0)!

        // Per-day totals in window
        var perDay: [Date: Int] = [:]
        for e in events {
            let d0 = cal.startOfDay(for: e.timestamp)
            if d0 >= start && d0 <= today0 {
                perDay[d0, default: 0] += e.quantity
            }
        }

        // Exponential decay
        let decay = exp(-log(2.0) / halfLifeDays)

        // Roll oldest → today
        var B = 0.0
        for i in 0..<lookbackDays {
            let day = cal.date(byAdding: .day, value: i - (lookbackDays - 1), to: today0)!
            let cigs = perDay[day] ?? 0
            let dose = pow(Double(cigs), p)
            B = B * decay + dose
        }

        // Normalize to 0...1 with smooth saturation
        let n = 1.0 - exp(-B / K)
        return max(0, min(1, n))
    }

    // MARK: - 7-level API (kept for compatibility)
    static func level(
        for events: [SmokeEvent],
        today: Date = Date(),
        halfLifeDays: Double = 10,
        p: Double = 1.15,
        K: Double = 50
    ) -> LungTintLevel {
        let n = severity(from: events, today: today, halfLifeDays: halfLifeDays, p: p, K: K)
        let bucket = min(6, max(0, Int(round(n * 6.0))))   // 0...6
        return LungTintLevel(rawValue: bucket) ?? .level1
    }

    // MARK: - Palettes
    static let palette7: [Color] = [
        Color(red: 0.13, green: 0.77, blue: 0.37), // Healthy (green)
        Color(red: 0.52, green: 0.80, blue: 0.09), // Yellow-green
        Color(red: 0.92, green: 0.70, blue: 0.03), // Yellow
        Color(red: 0.96, green: 0.62, blue: 0.04), // Orange
        Color(red: 0.98, green: 0.45, blue: 0.09), // Orange-red
        Color(red: 0.94, green: 0.27, blue: 0.27), // Red
        Color(red: 0.07, green: 0.09, blue: 0.15)  // Near-black
    ]

    // 14 finer steps (green → near-black)
    static let palette14: [Color] = [
        Color(red: 0.10, green: 0.78, blue: 0.38),
        Color(red: 0.18, green: 0.79, blue: 0.37),
        Color(red: 0.32, green: 0.81, blue: 0.30),
        Color(red: 0.42, green: 0.82, blue: 0.24),
        Color(red: 0.64, green: 0.84, blue: 0.14),
        Color(red: 0.84, green: 0.80, blue: 0.10),
        Color(red: 0.95, green: 0.72, blue: 0.08),
        Color(red: 0.97, green: 0.62, blue: 0.08),
        Color(red: 0.98, green: 0.52, blue: 0.10),
        Color(red: 0.97, green: 0.40, blue: 0.16),
        Color(red: 0.94, green: 0.30, blue: 0.22),
        Color(red: 0.87, green: 0.20, blue: 0.24),
        Color(red: 0.32, green: 0.18, blue: 0.20),
        Color(red: 0.08, green: 0.09, blue: 0.12)
    ]

    // MARK: - Palette-driven helpers
    static func color(
        for events: [SmokeEvent],
        palette: [Color] = palette7,
        today: Date = Date(),
        halfLifeDays: Double = 10,
        p: Double = 1.15,
        K: Double = 50
    ) -> Color {
        let n = severity(from: events, today: today, halfLifeDays: halfLifeDays, p: p, K: K)
        let idx = Int(round(n * Double(max(0, palette.count - 1))))
        return palette[min(max(0, idx), palette.count - 1)]
    }

    static func index(
        for events: [SmokeEvent],
        buckets: Int,
        today: Date = Date(),
        halfLifeDays: Double = 10,
        p: Double = 1.15,
        K: Double = 50
    ) -> Int {
        let n = severity(from: events, today: today, halfLifeDays: halfLifeDays, p: p, K: K)
        let idx = Int(round(n * Double(max(0, buckets - 1))))
        return min(max(0, idx), max(0, buckets - 1))
    }
    
    // 1…100 score mapped from severity (0…1)
    static func score100(
        for events: [SmokeEvent],
        today: Date = Date(),
        halfLifeDays: Double = 10,
        p: Double = 1.15,
        K: Double = 50
    ) -> Int {
        let n = severity(from: events, today: today, halfLifeDays: halfLifeDays, p: p, K: K)
        // 0 → 1, 1 → 100
        return max(1, min(100, 1 + Int(round(n * 99.0))))
    }

}
