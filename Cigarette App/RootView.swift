//
//  RootView.swift
//  Cigarette App
//
//  Created by Ashwin, Antony on 12/09/25.
//

import SwiftUI
import SwiftData

// Map Tier strings -> enum
extension CigTier {
    static func from(_ s: String) -> CigTier {
        switch s.lowercased() {
        case "common": return .common
        case "uncommon": return .uncommon
        case "rare": return .rare
        case "epic": return .epic
        case "legendary": return .legendary
        case "mythic": return .mythic
        case "exotic": return .exotic
        default: return .common
        }
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("seeded_v1") private var seededV1 = false

    var body: some View {
        TabView {
            NavigationStack { HomeDashboardView() }
                .tabItem { Label("Home", systemImage: "house") }

            NavigationStack { ManageTypesView() }
                .tabItem { Label("Manage", systemImage: "gearshape") }
        }
        .task { await seedIfNeeded() }
    }

    @MainActor
    private func seedIfNeeded() async {
        guard !seededV1 else { return }
        do {
            let count = try context.fetchCount(FetchDescriptor<CigType>())
            if count == 0 {
                for item in try loadDefaultCigs() {
                    context.insert(item)
                }
                try context.save()
            }
            seededV1 = true
        } catch {
            #if DEBUG
            print("Seeding error:", error)
            #endif
        }
    }

    private struct Seed: Decodable {
        let name: String
        let pack_size: Int
        let pack_price: Int
        let Tier: String
    }

    private func loadDefaultCigs() throws -> [CigType] {
        guard let url = Bundle.main.url(forResource: "DefaultCigs", withExtension: "json") else {
            throw NSError(domain: "Seed", code: 1, userInfo: [NSLocalizedDescriptionKey: "DefaultCigs.json not found in bundle"])
        }
        let data = try Data(contentsOf: url)
        let seeds = try JSONDecoder().decode([Seed].self, from: data)
        return seeds.map { s in
            CigType(
                name: s.name,
                packSize: s.pack_size,
                packPriceRupees: s.pack_price,
                notes: nil,
                isCommon: true,         // mark as common by default; tweak if you like
                isArchived: false,
                tier: CigTier.from(s.Tier)
            )
        }
    }
}
