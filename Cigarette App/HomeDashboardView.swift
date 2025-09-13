import SwiftUI
import SwiftData

struct HomeDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CigType.name) private var types: [CigType]
    @Query(sort: \SmokeEvent.timestamp, order: .reverse) private var events: [SmokeEvent]
    
    // at the top of the view with your other @State vars
    @State private var showHistory = false
    @State private var showNewType = false   // (you already have this)


    // MARK: - Derived data

    private var commonTypes: [CigType] {
        let favs = types.filter { $0.isCommon && !$0.isArchived }
        return favs.isEmpty ? types.filter { !$0.isArchived } : favs
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
        if let id = e.type?.id { m[id, default: 0] += e.quantity }
    }
    return m
}

    
    private var pages: [[CigType]] {
           guard !commonTypes.isEmpty else { return [] }
           var result: [[CigType]] = []
           var i = 0
           while i < commonTypes.count {
               let end = min(i + 4, commonTypes.count)
               result.append(Array(commonTypes[i..<end]))
               i = end
           }
           return result
       }
    

    private let cols = [GridItem(.flexible()), GridItem(.flexible())]

    // MARK: - UI

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) { // Restore default spacing between header, cards, and stats
                    // REPLACE your TabView block with this:
                    if commonTypes.isEmpty {
                        EmptyState(onAdd: { showNewType = true })
                    } else {
                        TabView {
                            ForEach(Array(pages.enumerated()), id: \.offset) { _, page in
                                CardGridPage(
                                    page: page,
                                    counts: todayCountByType,
                                    onAdd: { add(type: $0) },
                                    onMinus: { removeOne(type: $0) }
                                )
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                        }
                        .tabViewStyle(.page)
                        .indexViewStyle(.page(backgroundDisplayMode: .always))
                        .frame(minHeight: CGFloat((pages.first?.count ?? 1) * 110))
                    }

                    LungShape()
                        .breathing()     
                        .padding(.horizontal)
                        .padding(.top, 6)

                StatsPanel(
                    todayQty: todayQty,
                    todayCost: todayCost,
                    allQty: allQty,
                    allCost: allCost
                )
                .padding(.horizontal)
                // Remove .padding(.bottom, 16)
            }
            // Remove .padding(.bottom, 8)
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button { showHistory = true } label: {
                        Image(systemName: "clock")   // open history
                    }
                    Button { showNewType = true } label: {
                        Label("Add", systemImage: "plus")   // add cig type
                    }
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack { HistoryView() }     // <-- shows daily history (make sure you added HistoryView.swift)
        }
        .sheet(isPresented: $showNewType) { NewTypeSheet() }  // ensure this struct exists only once in the project

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
    
    private func removeOne(type: CigType) {
        let cal = Calendar.current
        if let ev = events.first(where: { $0.type?.id == type.id && cal.isDate($0.timestamp, inSameDayAs: Date()) }) {
            if ev.quantity > 1 { ev.quantity -= 1 } else { context.delete(ev) }
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        }
    }


}

private struct CigCard: View {
    let type: CigType
    let todayCount: Int
    let onAdd: () -> Void
    let onMinus: () -> Void

    // Tier visuals
    private var tierChip: some View {
        Text(type.tier.title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .foregroundStyle(type.tier.color)
            .background(type.tier.color.opacity(0.15), in: Capsule())
    }
    private var borderColor: Color { type.tier.color.opacity(0.35) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(type.name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    tierChip // ← badge now sits BELOW the name
                }
                Spacer()
                if todayCount > 0 {
                    Text("\(todayCount)")
                        .font(.caption.monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.15), in: Capsule())
                        .accessibilityLabel("Today: \(todayCount)")
                }
            }
            HStack {
                Text("₹\(type.costPerCigRupees)/cig")
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 14) {
                    Button(action: onMinus) {
                        Image(systemName: "minus.circle")
                            .font(.title2)
                    }
                    .disabled(todayCount == 0)
                    .opacity(todayCount == 0 ? 0.35 : 1.0)
                    .accessibilityLabel("Remove one \(type.name)")

                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add one \(type.name)")
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: type.tier == .mythic ? type.tier.color.opacity(0.2) : .clear,
                radius: type.tier == .mythic ? 6 : 0, x: 0, y: 0)
    }
}




private struct StatsPanel: View {
    let todayQty: Int, todayCost: Int
    let allQty: Int, allCost: Int

    var body: some View {
        VStack(spacing: 0) {
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
        VStack(spacing: 0) {
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

private struct CardGridPage: View {
    let page: [CigType]
    let counts: [PersistentIdentifier: Int]
    let onAdd: (CigType) -> Void
    let onMinus: (CigType) -> Void

    private let cols = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: cols, spacing: 8) {
            ForEach(page, id: \.id) { t in
                let count = counts[t.id] ?? 0
                CigCard(
                    type: t,
                    todayCount: count,
                    onAdd: { onAdd(t) },
                    onMinus: { onMinus(t) }
                )
            }
        }
    }
}



