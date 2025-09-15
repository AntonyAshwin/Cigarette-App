import SwiftUI
import SwiftData
import Charts      // ← ADD THIS

struct HomeDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CigType.name) private var types: [CigType]
    @Query(sort: \SmokeEvent.timestamp, order: .reverse) private var events: [SmokeEvent]
    
    // at the top of the view with your other @State vars
    @State private var showHistory = false
    @State private var showNewType = false   // (you already have this)
    @State private var editingType: CigType?


    // MARK: - Derived data

    private var commonTypes: [CigType] {
        let favs = types.filter { $0.isCommon && !$0.isArchived }
        return favs.isEmpty ? types.filter { !$0.isArchived } : favs
    }

    private var lungLevel: LungTintLevel {
    LungColorEngine.level(for: events)
}
    
    // Text label beside the score (uses your 7-level enum: Healthy, Strained, etc.)
    private var lungLabel: String {
        LungColorEngine.level(for: events).label
    }

    
    private var lungScore100: Int {
        101 - LungColorEngine.score100(for: events)   // 100 = best, 1 = worst
    }



    private var todayEvents: [SmokeEvent] {
        let cal = Calendar.current
        return events.filter { cal.isDate($0.timestamp, inSameDayAs: Date()) }
    }

    private var lungTint: Color {
    LungColorEngine.color(for: events, palette: LungColorEngine.palette14)
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
                VStack(spacing: 16) {
                    streakSection
                    cardsPagerSection
                    LungsSection(
                        events: events,
                        tint: lungTint,
                        score: lungScore100,
                        maxScore: 100,
                        label: lungLabel
                    )
                    .padding(.horizontal)

                    StatsPanel(
                        todayQty: todayQty,
                        todayCost: todayCost,
                        allQty: allQty,
                        allCost: allCost
                    )
                    .padding(.horizontal)
                }
                .padding(.top, 8)
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button { showHistory = true } label: { Image(systemName: "clock") }
                        Button { showNewType = true } label: { Image(systemName: "plus") }
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                NavigationStack { HistoryView() }
            }
            .sheet(isPresented: $showNewType) { NewTypeSheet() }
            .sheet(item: $editingType) { type in
                QuickQtySheet(
                    typeName: type.name,
                    initialQty: qtyToday(for: type),
                    onSave: { newQty in applyQty(for: type, newQty: newQty) }
                )
            }
        }
    }

    // MARK: - Extracted Sections

    @ViewBuilder
    private var streakSection: some View {
        StreakPill(days: streakDays)
            .padding(.horizontal)
    }

    @ViewBuilder
    private var cardsPagerSection: some View {
        if commonTypes.isEmpty {
            EmptyState(onAdd: { showNewType = true })
                .padding(.horizontal)
        } else {
            CardsPager(
                pages: pages,
                counts: todayCountByType,
                onAdd: { add(type: $0) },
                onMinus: { removeOne(type: $0) },
                onTap: { editingType = $0 }
            )
            .frame(height: pagerHeight)
            .padding(.horizontal)
        }
    }

    private var pagerHeight: CGFloat {
        // Simplified dynamic height
        let first = pages.first?.count ?? 1
        let rows = Int(ceil(Double(first) / 2.0))
        return CGFloat(rows * 150)
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
    
    // Consecutive full smoke-free days ending yesterday
    private var streakDays: Int { smokeFreeStreak(events: events) }

    private func smokeFreeStreak(events: [SmokeEvent]) -> Int {
        let cal = Calendar.current
        let today0 = cal.startOfDay(for: Date())
        // All days that have at least one event
        let eventDays = Set(events.map { cal.startOfDay(for: $0.timestamp) })

        var streak = 0
        // Start from yesterday so we only count completed smoke-free days
        var day = cal.date(byAdding: .day, value: -1, to: today0)!

        while !eventDays.contains(day) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    
    private func qtyToday(for type: CigType) -> Int {
        todayCountByType[type.id] ?? 0
    }

    private func applyQty(for type: CigType, newQty: Int) {
        let cal = Calendar.current
        if let ev = events.first(where: { $0.type?.id == type.id && cal.isDate($0.timestamp, inSameDayAs: Date()) }) {
            if newQty <= 0 {
                context.delete(ev)                    // remove today’s event if 0
            } else {
                ev.quantity = newQty                 // edit today’s event
            }
        } else if newQty > 0 {
            context.insert(SmokeEvent(quantity: newQty, type: type))  // create today’s event
        }
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
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
        VStack() {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
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
                HStack() {
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
        VStack() {
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
        VStack() {
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
    let onTap: (CigType) -> Void        

    private let cols = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: cols) {
            ForEach(page, id: \.id) { t in
                let count = counts[t.id] ?? 0
                CigCard(
                    type: t,
                    todayCount: count,
                    onAdd: { onAdd(t) },
                    onMinus: { onMinus(t) }
                )
                .contentShape(Rectangle())   
                .onTapGesture { onTap(t) }   
            }
        }
    }
}


private struct LungsAndScoreRow: View {
    let tint: Color
    let score: Int
    let maxScore: Int
    let label: String

    var body: some View {
        HStack(spacing: 16) {
            LungShape(tint: tint, breathing: true)
                .frame(width: 140, height: 140)

            VStack(alignment: .leading, spacing: 8) {
                Text("Lung score")
                    .font(.headline)

                Text("\(score)\u{00A0}/\u{00A0}\(maxScore)")
    .font(.system(size: 34, weight: .semibold, design: .rounded))
    .monospacedDigit()
    .lineLimit(1)
    .minimumScaleFactor(0.85)


                // Optional progress bar
                ProgressView(value: Double(score), total: Double(maxScore))
                    .tint(tint)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct StreakPill: View {
    let days: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.title3)
                .foregroundStyle(days > 0 ? .orange : .secondary)

            HStack(spacing: 4) {
                Text("\(days)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(days == 1 ? "day" : "days")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke((days > 0 ? Color.orange : Color.secondary).opacity(0.25), lineWidth: 1)
        )
        .accessibilityLabel("Smoke-free streak: \(days) \(days == 1 ? "day" : "days")")
    }
}




private struct QuickQtySheet: View {
    let typeName: String
    let initialQty: Int
    let onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var qtyText: String
    @State private var qty: Int

    init(typeName: String, initialQty: Int, onSave: @escaping (Int) -> Void) {
        self.typeName = typeName
        self.initialQty = initialQty
        self.onSave = onSave
        _qty = State(initialValue: max(0, initialQty))
        _qtyText = State(initialValue: String(max(0, initialQty)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(typeName)) {
                    Stepper(value: $qty, in: 0...60) {
                        HStack {
                            Text("Today’s count")
                            Spacer()
                            Text("\(qty)").monospacedDigit()
                        }
                    }
                    HStack {
                        Text("Enter Quantity ")
                        Spacer()
                        TextField("", text: $qtyText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: qtyText) { _, newVal in
                                let v = Int(newVal) ?? qty
                                qty = max(0, min(60, v))
                            }
                            .onChange(of: qty) { _, v in
                                qtyText = String(v)
                            }
                    }
                    if initialQty > 0 {
                        Button(role: .destructive) {
                            qty = 0
                            onSave(0)
                            dismiss()
                        } label: {
                            Label("Clear today’s entry", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Set Today’s Count")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(qty)
                        dismiss()
                    }
                    .disabled(qty < 0)
                }
            }
        }
    }
}

// ADD NEW SECTION + CHART TYPES (place near bottom, before QuickQtySheet or after StreakPill)
private struct LungsSection: View {
    let events: [SmokeEvent]
    let tint: Color
    let score: Int
    let maxScore: Int
    let label: String

    @State private var lookbackDays: Int = 30   // could expose UI later

    var body: some View {
        TabView {
            LungsAndScoreRow(tint: tint, score: score, maxScore: maxScore, label: label)
                .padding(.vertical, 2)

            LungsProgressChart(events: events, tint: tint, lookbackDays: lookbackDays)
                .padding(.vertical, 8)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(height: 200)   // height for both pages
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lung status and progress")
    }
}

private struct LungsProgressChart: View {
    let events: [SmokeEvent]
    let tint: Color
    let lookbackDays: Int

    private struct Point: Identifiable {
        let day: Date
        let score: Int
        var id: Date { day }
    }

    // Explicit type + simple builder
    private var points: [Point] {
        let cal = Calendar.current
        let today0 = cal.startOfDay(for: Date())
        return (0..<lookbackDays).compactMap { i in
            guard let day = cal.date(byAdding: .day,
                                     value: -(lookbackDays - 1 - i),
                                     to: today0) else { return nil }
            let s = 101 - LungColorEngine.score100(for: events, today: day)
            return Point(day: day, score: s)
        }
    }

    private var yTicks: [Int] { [0, 25, 50, 75, 100] }

    // Extract the chart to reduce complexity in body
    @ViewBuilder
    private var progressChart: some View {
        Chart {
            ForEach(points) { p in
                AreaMark(
                    x: .value("Day", p.day),
                    y: .value("Score", p.score)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(tint.opacity(0.25).gradient)

                LineMark(
                    x: .value("Day", p.day),
                    y: .value("Score", p.score)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(tint)

                PointMark(
                    x: .value("Day", p.day),
                    y: .value("Score", p.score)
                )
                .foregroundStyle(tint)
                .symbolSize(16)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yTicks) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartXScale(domain: (points.first?.day ?? Date())...(points.last?.day ?? Date()))
        .chartYScale(domain: 0...100)
        .frame(height: 140)
        .accessibilityHidden(true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress (\(lookbackDays) days)")
                .font(.headline)

            if points.isEmpty {
                Text("No data yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                progressChart
            }

            Text("Higher score indicates better lung status.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Lightweight wrapper to reduce generic complexity
private struct CardsPager: View {
    let pages: [[CigType]]
    let counts: [PersistentIdentifier: Int]
    let onAdd: (CigType) -> Void
    let onMinus: (CigType) -> Void
    let onTap: (CigType) -> Void

    var body: some View {
        TabView {
            ForEach(Array(pages.enumerated()), id: \.offset) { _, page in
                CardGridPage(
                    page: page,
                    counts: counts,
                    onAdd: onAdd,
                    onMinus: onMinus,
                    onTap: onTap
                )
                .padding(.vertical, 8)
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}





