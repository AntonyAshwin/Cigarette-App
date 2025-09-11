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
    private var todayQty: Int { todayEvents.map(\.quantity).reduce(0, +) }
    private var todayCost: Int { todayEvents.map { $0.quantity * $0.type.costPerCigRupees }.reduce(0, +) }

    struct Row: Identifiable {
        let id: PersistentIdentifier
        let type: CigType
        let qty: Int
        let cost: Int
    }
    private var rowsByType: [Row] {
        var m: [PersistentIdentifier: (type: CigType, qty: Int, cost: Int)] = [:]
        for e in todayEvents {
            let id = e.type.id
            var entry = m[id] ?? (e.type, 0, 0)
            entry.qty += e.quantity
            entry.cost += e.quantity * e.type.costPerCigRupees
            m[id] = entry
        }
        return m.map { Row(id: $0.key, type: $0.value.type, qty: $0.value.qty, cost: $0.value.cost) }
                .sorted { $0.type.name < $1.type.name }
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
                                Text(row.type.name)
                                Text("₹\(row.type.costPerCigRupees) per cig")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(row.qty)").monospacedDigit()
                            Text("•").foregroundStyle(.secondary)
                            Text("₹\(row.cost)").monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(row.type.name), \(row.qty) cigarettes, cost ₹\(row.cost)")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
