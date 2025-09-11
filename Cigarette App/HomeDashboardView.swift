import SwiftUI
import SwiftData

struct HomeDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CigType.name) private var types: [CigType]
    @Query(sort: \SmokeEvent.timestamp, order: .reverse) private var events: [SmokeEvent]

    @State private var showNewType = false

    // MARK: - Derived data

    private var commonTypes: [CigType] {
        let favs = types.filter { $0.isCommon }
        return favs.isEmpty ? types : favs
    }

    private var todayEvents: [SmokeEvent] {
        let cal = Calendar.current
        return events.filter { cal.isDate($0.timestamp, inSameDayAs: Date()) }
    }

    private var todayQty: Int { todayEvents.map(\.quantity).reduce(0, +) }
    private var todayCost: Int { todayEvents.map(\.costRupees).reduce(0, +) }
    private var allQty: Int { events.map(\.quantity).reduce(0, +) }
    private var allCost: Int { events.map(\.costRupees).reduce(0, +) }

    // Precompute "today count by type" to avoid heavy inline filters in ForEach
    private var todayCountByType: [PersistentIdentifier: Int] {
        var m: [PersistentIdentifier: Int] = [:]
        for e in todayEvents {
            m[e.type.id, default: 0] += e.quantity
        }
        return m
    }

    private let cols = [GridItem(.flexible()), GridItem(.flexible())]

    // MARK: - UI

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Top grid
                ScrollView {
                    LazyVGrid(columns: cols, spacing: 12) {
                        if commonTypes.isEmpty {
                            EmptyState(onAdd: { showNewType = true })
                        } else {
                            ForEach(commonTypes, id: \.id) { t in
                                let count = todayCountByType[t.id] ?? 0
                                CigCard(
                                    type: t,
                                    todayCount: count,
                                    onAdd: { add(type: t) }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }

                // Bottom stats (day + overall)
                StatsPanel(
                    todayQty: todayQty,
                    todayCost: todayCost,
                    allQty: allQty,
                    allCost: allCost
                )
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewType = true } label: { Label("Add", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $showNewType) { NewTypeSheet() } // make sure you only define this struct once in your project
        }
    }

    // MARK: - Actions

    private func add(type: CigType) {
        let ev = SmokeEvent(quantity: 1, type: type)
        context.insert(ev)
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// MARK: - Subviews

private struct CigCard: View {
    let type: CigType
    let todayCount: Int
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(type.name).font(.headline).lineLimit(1)
                Spacer()
                if todayCount > 0 {
                    Text("\(todayCount)")
                        .font(.caption.monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.15), in: Capsule())
                }
            }
            HStack {
                Text("₹\(type.costPerCigRupees)/cig").foregroundStyle(.secondary)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add one \(type.name)")
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct StatsPanel: View {
    let todayQty: Int, todayCost: Int
    let allQty: Int, allCost: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack { Text("Today").font(.headline); Spacer() }
            HStack {
                VStack(alignment: .leading) {
                    Text("Cigarettes").foregroundStyle(.secondary)
                    Text("\(todayQty)").font(.title2.weight(.semibold)).monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Expense").foregroundStyle(.secondary)
                    Text("₹\(todayCost)").font(.title2.weight(.semibold)).monospacedDigit()
                }
            }
            Divider()
            HStack { Text("Overall").font(.headline); Spacer() }
            HStack {
                VStack(alignment: .leading) {
                    Text("Cigarettes").foregroundStyle(.secondary)
                    Text("\(allQty)").font(.title2.weight(.semibold)).monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Expense").foregroundStyle(.secondary)
                    Text("₹\(allCost)").font(.title2.weight(.semibold)).monospacedDigit()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct EmptyState: View {
    let onAdd: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            Text("No cigarettes set").font(.headline)
            Text("Tap Add to create your first type with price.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: onAdd) { Label("Add", systemImage: "plus") }
                .buttonStyle(.bordered)
                .padding(.top, 4)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}
