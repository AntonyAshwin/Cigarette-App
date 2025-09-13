import SwiftUI
import SwiftData

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
                VStack() { // Restore default spacing between header, cards, and stats
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
                                    onMinus: { removeOne(type: $0) },
                                    onTap: { editingType = $0 }      // 👈 open editor on tap
                                )

                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                        }
                        .tabViewStyle(.page)
                        .indexViewStyle(.page(backgroundDisplayMode: .always))
                        .frame(minHeight: CGFloat((pages.first?.count ?? 1) * 110))
                    }

                    LungsAndScoreRow(
                        tint: lungTint,               // or lungLevel.color
                        score: lungScore100,
                        maxScore: 100,
                        label: lungLabel
                    )
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
        .sheet(item: $editingType) { type in
    QuickQtySheet(
        typeName: type.name,
        initialQty: qtyToday(for: type),
        onSave: { newQty in
            applyQty(for: type, newQty: newQty)
        }
    )
}

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

                Text("\(score) / \(maxScore)")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()

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





