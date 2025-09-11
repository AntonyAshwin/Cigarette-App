import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \SmokeEvent.timestamp, order: .reverse) private var events: [SmokeEvent]

    // Group events by day
    private var days: [(date: Date, qty: Int, cost: Int)] {
        var bucket: [Date: (qty: Int, cost: Int)] = [:]
        let cal = Calendar.current

        for e in events {
            let day = cal.startOfDay(for: e.timestamp)
            var entry = bucket[day] ?? (0, 0)
            entry.qty  += e.quantity
            entry.cost += e.quantity * e.type.costPerCigRupees
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
        .listStyle(.insetGrouped)
    }
}

// Per-day breakdown by type
struct DayDetailView: View {
    @Query(sort: \SmokeEvent.timestamp, order: .reverse) private var allEvents: [SmokeEvent]
    let date: Date

    private var rows: [(typeName: String, qty: Int, cost: Int)] {
        let cal = Calendar.current
        let dayEvents = allEvents.filter { cal.isDate($0.timestamp, inSameDayAs: date) }

        var bucket: [PersistentIdentifier: (name: String, qty: Int, cost: Int)] = [:]
        for e in dayEvents {
            let id = e.type.id
            var entry = bucket[id] ?? (e.type.name, 0, 0)
            entry.qty  += e.quantity
            entry.cost += e.quantity * e.type.costPerCigRupees
            bucket[id] = entry
        }

        // Map the value tuple (name, qty, cost) -> (typeName, qty, cost) so labels match
        return bucket.values
            .map { (typeName: $0.name, qty: $0.qty, cost: $0.cost) }
            .sorted { $0.typeName < $1.typeName }
    }


    var body: some View {
        List {
            Section {
                HStack {
                    Text(date, style: .date).font(.headline)
                    Spacer()
                }
            }
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
        }
        .navigationTitle("Details")
        .listStyle(.insetGrouped)
    }
}
