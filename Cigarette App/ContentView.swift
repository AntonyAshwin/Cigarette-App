import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CigType.name) private var types: [CigType]
    @Query(sort: \SmokeEvent.timestamp, order: .reverse) private var events: [SmokeEvent]

    @State private var selectedTypeID: PersistentIdentifier?
    @State private var showAddType = false
    @State private var showManage = false
    @State private var qty: Int = 1

    private var selectedType: CigType? {
        if let id = selectedTypeID { return types.first(where: { $0.id == id }) }
        return types.first
    }

    private var todayEvents: [SmokeEvent] {
        let cal = Calendar.current
        return events.filter { cal.isDate($0.timestamp, inSameDayAs: Date()) }
    }
    private var todayQty: Int {
        todayEvents.map(\.quantity).reduce(0, +)
    }
    private var todayCost: Int {
        // prefer the snapshot so history stays correct even if type was deleted/price changed
        todayEvents.map { $0.quantity * $0.unitCostRupeesSnapshot }.reduce(0, +)
        // If you prefer current price when available, you could do:
        // todayEvents.map { $0.quantity * ($0.type?.costPerCigRupees ?? $0.unitCostRupeesSnapshot) }.reduce(0, +)
    }

    // Inside ContentView

    struct Row: Identifiable {
        let typeName: String       // from snapshot if type is gone
        let unit: Int              // ₹ per cig (snapshot or current)
        let qty: Int
        let cost: Int
        var id: String { typeName } // stable ID for ForEach
    }

    private var rowsByType: [Row] {
        var bucket: [String:(unit: Int, qty: Int, cost: Int)] = [:]
        for e in todayEvents {
            let name = e.type?.name ?? e.typeNameSnapshot
            let unit = e.type?.costPerCigRupees ?? e.unitCostRupeesSnapshot
            var entry = bucket[name] ?? (unit, 0, 0)
            entry.qty  += e.quantity
            entry.cost += e.quantity * unit
            entry.unit  = unit  // in case price changed during the day, keep last seen
            bucket[name] = entry
        }
        return bucket
            .map { Row(typeName: $0.key, unit: $0.value.unit, qty: $0.value.qty, cost: $0.value.cost) }
            .sorted { $0.typeName < $1.typeName }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                typePicker

                Stepper(value: $qty, in: 1...5) { Text("Quantity: \(qty)") }
                    .disabled(types.isEmpty)

                Button { addEvent() } label: {
                    Text("Add \(qty)")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(types.isEmpty)

                todaySummary

                TodayByTypeList(rows: rowsByType)

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Cigarette Count")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showManage = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showAddType = true } label: { Label("Add", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $showAddType) { NewTypeSheet() }
            .sheet(isPresented: $showManage)  { ManageTypesView() }
            .onAppear { if selectedTypeID == nil { selectedTypeID = types.first?.id } }
        }
    }

    private var typePicker: some View {
        Group {
            if types.isEmpty {
                VStack(spacing: 8) {
                    Text("No types yet").font(.headline)
                    Button { showAddType = true } label: { Label("Create first type", systemImage: "plus.circle") }
                }
            } else {
                Picker("Type", selection: Binding(
                    get: { selectedType },
                    set: { selectedTypeID = $0?.id }
                )) {
                    ForEach(types, id: \.id) { t in
                        Text("\(t.name) • ₹\(t.costPerCigRupees)/cig").tag(Optional(t))
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var todaySummary: some View {
        VStack(spacing: 6) {
            Text("Today").font(.headline)
            HStack {
                Text("Total: \(todayQty)").font(.title2.weight(.semibold))
                Spacer()
                Text("Cost: ₹\(todayCost)").font(.title2.weight(.semibold))
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func addEvent() {
        guard let t = selectedType else { return }
        context.insert(SmokeEvent(timestamp: .now, quantity: qty, type: t))
        qty = 1
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

private struct TodayByTypeList: View {
    let rows: [ContentView.Row]

    var body: some View {
        List {
            Section("Today by Type") {
                if rows.isEmpty {
                    Text("No entries yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(rows) { row in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(row.typeName)
                                Text("₹\(row.unit) per cig")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(row.qty)").monospacedDigit()
                            Text("•").foregroundStyle(.secondary)
                            Text("₹\(row.cost)").monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(row.typeName), \(row.qty) cigarettes, cost ₹\(row.cost)")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

