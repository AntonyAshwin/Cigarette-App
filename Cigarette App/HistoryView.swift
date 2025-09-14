// File: HistoryView.swift
import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \SmokeEvent.timestamp, order: .reverse) private var events: [SmokeEvent]
    @Environment(\.modelContext) private var context
    
    @State private var showMoveSheet = false
    @State private var moveSourceDate = Date()


    @State private var addingToday = false
    @State private var confirmDeleteDate: Date?

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
                            Text(day.date, style: .date).font(.headline)
                            Text(day.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(day.qty)").monospacedDigit()
                            Text("₹\(day.cost)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button("Move Day…") {
                        moveSourceDate = day.date
                        showMoveSheet = true
                    }
                    .tint(.blue)

                    Button(role: .destructive) {
                        confirmDeleteDate = day.date
                    } label: {
                        Label("Delete Day", systemImage: "trash")
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
            // Your existing editor; defaults to "now"
            EventEditorSheet()
        }
        .sheet(isPresented: $showMoveSheet) {
            MoveDaySheet(current: moveSourceDate) { newDate in
                moveAllEvents(from: moveSourceDate, to: newDate)
            }
        }

        .listStyle(.insetGrouped)

        // Confirm delete WHOLE DAY
        .alert(
            "Delete all entries for this day?",
            isPresented: Binding(
                get: { confirmDeleteDate != nil },
                set: { if !$0 { confirmDeleteDate = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let d = confirmDeleteDate { deleteAll(on: d) }
                confirmDeleteDate = nil
            }
            Button("Cancel", role: .cancel) { confirmDeleteDate = nil }
        } message: {
            if let d = confirmDeleteDate {
                let count = countEntries(on: d)
                Text("\(d.formatted(date: .abbreviated, time: .omitted)) • This will delete \(count) entr\(count == 1 ? "y" : "ies").")
            }
        }
    }

    private func deleteAll(on date: Date) {
        let cal = Calendar.current
        for e in events where cal.isDate(e.timestamp, inSameDayAs: date) {
            context.delete(e)
        }
    }

    private func countEntries(on date: Date) -> Int {
        let cal = Calendar.current
        return events.filter { cal.isDate($0.timestamp, inSameDayAs: date) }.count
    }
    
    private func moveAllEvents(from source: Date, to target: Date) {
        let cal = Calendar.current
        // If user picked the same day, nothing to do
        guard !cal.isDate(source, inSameDayAs: target) else { return }

        let targetStart = cal.startOfDay(for: target)

        for e in events where cal.isDate(e.timestamp, inSameDayAs: source) {
            let t = e.timestamp
            let c = cal.dateComponents([.hour, .minute, .second], from: t)
            e.timestamp = cal.date(bySettingHour: c.hour ?? 12,
                                   minute: c.minute ?? 0,
                                   second: c.second ?? 0,
                                   of: targetStart) ?? targetStart
        }
    }

}

private struct MoveDaySheet: View {
    @Environment(\.dismiss) private var dismiss
    let current: Date
    let onSave: (Date) -> Void

    @State private var target: Date

    init(current: Date, onSave: @escaping (Date) -> Void) {
        self.current = current
        self.onSave = onSave
        _target = State(initialValue: current)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("New date", selection: $target, displayedComponents: .date)
            }
            .navigationTitle("Move Day")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(target)
                        dismiss()
                    }
                }
            }
        }
    }
}


// MARK: - Day details (same file)
struct DayDetailView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SmokeEvent.timestamp, order: .reverse) private var allEvents: [SmokeEvent]
    let date: Date

    @State private var editing: SmokeEvent?
    @State private var adding = false

    private var dayEvents: [SmokeEvent] {
        let cal = Calendar.current
        return allEvents
            .filter { cal.isDate($0.timestamp, inSameDayAs: date) }
            .sorted { $0.timestamp < $1.timestamp }
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
                        .onTapGesture { editing = e }     // tap to edit
                        .swipeActions {
                            Button("Edit") { editing = e }
                            Button(role: .destructive) {
                                context.delete(e)           // delete single entry
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { idx in
                        for i in idx { context.delete(dayEvents[i]) }  // edit-mode delete
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
        // Use your existing editor (no redeclaration)
        .sheet(isPresented: $adding) { EventEditorSheet(event: nil, defaultDate: date) }
        .sheet(item: $editing)      { EventEditorSheet(event: $0) }
        .listStyle(.insetGrouped)
    }
}
