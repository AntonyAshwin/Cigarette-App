import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \SmokeEvent.timestamp, order: .reverse) private var events: [SmokeEvent]
    @State private var addingToday = false

    // Group events by day
    private var days: [(date: Date, qty: Int, cost: Int)] {
        var bucket: [Date: (qty: Int, cost: Int)] = [:]
        let cal = Calendar.current

        for e in events {
            let day = cal.startOfDay(for: e.timestamp)
            var entry = bucket[day] ?? (0, 0)
            entry.qty  += e.quantity
            entry.cost += e.quantity * e.unitCostRupeesSnapshot
            bucket[day] = entry
        }

        return bucket
            .map { ($0.key, $0.value.qty, $0.value.cost) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            ForEach(days, id: \.date) { day in
                NavigationLink {
                    DayDetailView(date: day.date)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(day.date, style: .date)
                                .font(.headline)
                            Text(day.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(day.qty)").monospacedDigit()
                            Text("₹\(day.cost)").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { addingToday = true } label: { Label("Add", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $addingToday) {
            // Add a new entry defaulting to now (today)
            EventEditorSheet()
        }
        .listStyle(.insetGrouped)
    }
}

// Per-day breakdown: summary by type + editable entry list
struct DayDetailView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SmokeEvent.timestamp, order: .reverse) private var allEvents: [SmokeEvent]
    let date: Date

    @State private var editing: SmokeEvent?
    @State private var adding = false

    private var dayEvents: [SmokeEvent] {
        let cal = Calendar.current
        return allEvents.filter { cal.isDate($0.timestamp, inSameDayAs: date) }
    }

    // Summary by type (snapshot-safe)
    private var rows: [(typeName: String, qty: Int, cost: Int)] {
        var bucket: [String:(qty:Int, cost:Int)] = [:]
        for e in dayEvents {
            let name = e.displayTypeName
            let unit = e.unitCostRupeesSnapshot
            var entry = bucket[name] ?? (0, 0)
            entry.qty  += e.quantity
            entry.cost += e.quantity * unit
            bucket[name] = entry
        }
        return bucket
            .map { (typeName: $0.key, qty: $0.value.qty, cost: $0.value.cost) }
            .sorted { $0.typeName < $1.typeName }
    }

    var body: some View {
        List {
            // Summary
            Section("By Type") {
                if rows.isEmpty {
                    Text("No entries.").foregroundStyle(.secondary)
                } else {
                    ForEach(rows, id: \.typeName) { r in
                        HStack {
                            Text(r.typeName)
                            Spacer()
                            Text("\(r.qty)").monospacedDigit()
                            Text("•").foregroundStyle(.secondary)
                            Text("₹\(r.cost)").monospacedDigit()
                        }
                    }
                }
            }

            // Editable entries
            Section("Entries") {
                if dayEvents.isEmpty {
                    Text("No entries.").foregroundStyle(.secondary)
                } else {
                    ForEach(dayEvents) { e in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(e.displayTypeName).font(.headline)
                                Text("₹\(e.unitCostRupeesSnapshot) per cig")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(e.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 6) {
                                    Text("\(e.quantity)").monospacedDigit()
                                    Text("•").foregroundStyle(.secondary)
                                    Text("₹\(e.costRupees)").monospacedDigit()
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editing = e }
                        .swipeActions {
                            Button("Edit") { editing = e }
                            Button(role: .destructive) {
                                context.delete(e)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                    .onDelete { idx in
                        for i in idx { context.delete(dayEvents[i]) }
                    }
                }
            }
        }
        .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { adding = true } label: { Label("Add", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $adding) { EventEditorSheet(event: nil, defaultDate: date) }
        .sheet(item: $editing)      { EventEditorSheet(event: $0) }
        .listStyle(.insetGrouped)
    }
}
