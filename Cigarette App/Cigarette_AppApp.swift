import SwiftUI
import SwiftData

@main
struct Cigarette_AppApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootTab() // <- same TabView UI, with seeding wired in
        }
        .modelContainer(for: [CigType.self, SmokeEvent.self])
    }
}

// MARK: - Tab root with first-launch seeding

private struct AppRootTab: View {
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

    // MARK: Seeding

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

    // Map Tier strings from JSON -> enum
    private func tierFrom(_ s: String) -> CigTier {
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

    // JSON shape
    private struct Seed: Decodable {
        let name: String
        let pack_size: Int
        let pack_price: Int
        let Tier: String
    }
    
    // Which seeded items should be marked as favourites
    private func isFavorite(_ name: String) -> Bool {
        let n = name.lowercased()
        return n.contains("light") || n.contains("lights")   // any “Lights”
            || n == "marlboro red".lowercased()             // exactly Marlboro Red
            || n.contains("connect")                         // Classic Connect
            || n.contains("shift")                           // Stellar Shift (both)
    }


    // Try to load DefaultCigs.json from the app bundle; if not found, fall back to the hardcoded list
    private func loadDefaultCigs() throws -> [CigType] {
        if let url = Bundle.main.url(forResource: "DefaultCigs", withExtension: "json") {
            let data = try Data(contentsOf: url)
            let seeds = try JSONDecoder().decode([Seed].self, from: data)
            // JSON path
            return seeds.map { s in
                CigType(
                    name: s.name,
                    packSize: s.pack_size,
                    packPriceRupees: s.pack_price,
                    notes: nil,
                    isCommon: isFavorite(s.name),   // ← HERE
                    isArchived: false,
                    tier: tierFrom(s.Tier)
                )
            }

        } else {
            // Fallback data (same as you shared)
            let fallback: [Seed] = [
                .init(name: "Benson & Hedges Gold", pack_size: 20, pack_price: 350, Tier: "Legendary"),
                .init(name: "Berkeley Regular", pack_size: 20, pack_price: 190, Tier: "Epic"),
                .init(name: "Capstan Regular", pack_size: 20, pack_price: 180, Tier: "Rare"),
                .init(name: "Classic Connect", pack_size: 20, pack_price: 300, Tier: "Common"),
                .init(name: "Classic Milds", pack_size: 20, pack_price: 220, Tier: "Common"),
                .init(name: "Classic Regular", pack_size: 20, pack_price: 230, Tier: "Uncommon"),
                .init(name: "Four Square Regular", pack_size: 20, pack_price: 180, Tier: "Epic"),
                .init(name: "Gold Flake Kings", pack_size: 20, pack_price: 240, Tier: "Common"),
                .init(name: "Gold Flake Lights", pack_size: 20, pack_price: 250, Tier: "Uncommon"),
                .init(name: "Gold Flake Neo", pack_size: 20, pack_price: 260, Tier: "Epic"),
                .init(name: "India Kings", pack_size: 20, pack_price: 250, Tier: "Rare"),
                .init(name: "Marlboro Advance", pack_size: 20, pack_price: 300, Tier: "Epic"),
                .init(name: "Marlboro Gold", pack_size: 20, pack_price: 330, Tier: "Legendary"),
                .init(name: "Marlboro Red", pack_size: 20, pack_price: 320, Tier: "Legendary"),
                .init(name: "ROYAL SWAG Herbal", pack_size: 10, pack_price: 180, Tier: "Exotic"),
                .init(name: "Red & White Special", pack_size: 20, pack_price: 200, Tier: "Mythic"),
                .init(name: "Stellar Shift Millennium", pack_size: 20, pack_price: 200, Tier: "Common"),
                .init(name: "Stellar Shift Mint", pack_size: 20, pack_price: 200, Tier: "Uncommon"),
                .init(name: "Wills Navy Cut Regular", pack_size: 20, pack_price: 230, Tier: "Epic"),
                .init(name: "Wills Navy Cut Lights", pack_size: 20, pack_price: 240, Tier: "Epic")
            ]

            return fallback.map { s in
                CigType(
                    name: s.name,
                    packSize: s.pack_size,
                    packPriceRupees: s.pack_price,
                    notes: nil,
                    isCommon: isFavorite(s.name),   // ← AND HERE
                    isArchived: false,
                    tier: tierFrom(s.Tier)
                )
            }

        }
    }
}
