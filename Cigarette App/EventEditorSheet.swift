import SwiftUI
import SwiftData

struct EventEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \CigType.name) private var allTypes: [CigType]

    // If nil → Add mode. If non-nil → Edit mode.
    let existing: SmokeEvent?
    let defaultDate: Date

    // UI State
    @State private var date: Date
    @State private var qty: Int
    @State private var note: String
    @State private var selectedTypeID: PersistentIdentifier?   // nil = custom
    @State private var customName: String
    @State private var customUnit: String                      // ₹ per cig

    init(event: SmokeEvent? = nil, defaultDate: Date = .now) {
        self.existing = event
        self.defaultDate = defaultDate

        _date = State(initialValue: event?.timestamp ?? defaultDate)
        _qty  = State(initialValue: event?.quantity ?? 1)
        _note = State(initialValue: event?.note ?? "")

        if let ev = event {
            if let t = ev.type {
                _selectedTypeID = State(initialValue: t.id)
                _customName = State(initialValue: t.name)
                _customUnit = State(initialValue: String(t.costPerCigRupees))
            } else {
                _selectedTypeID = State(initialValue: nil)
                _customName = State(initialValue: ev.typeNameSnapshot)
                _customUnit = State(initialValue: String(ev.unitCostRupeesSnapshot))
            }
        } else {
            _selectedTypeID = State(initialValue: nil)
            _customName = State(initialValue: "")
            _customUnit = State(initialValue: "")
        }
    }

    private var selectedType: CigType? {
        guard let id = selectedTypeID else { return nil }
        return allTypes.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Date & time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Type") {
                    Picker("Choose", selection: $selectedTypeID) {
                        Text("Custom (deleted/other)").tag(PersistentIdentifier?.none)
                        ForEach(allTypes, id: \.id) { t in
                            Text(t.name).tag(Optional(t.id))
                        }
                    }
                    .pickerStyle(.menu)

                    if selectedType == nil {
                        TextField("Name (e.g. Old Brand)", text: $customName)
                        TextField("₹ per cig (whole)", text: $customUnit)
                            .keyboardType(.numberPad)
                    }
                }

                Section("Quantity") {
                    Stepper(value: $qty, in: 1...40) {
                        Text("\(qty) cigarette\(qty == 1 ? "" : "s")")
                            .monospacedDigit()
                    }
                }

                Section("Note") {
                    TextField("Optional note", text: $note)
                }
            }
            .navigationTitle(existing == nil ? "Add History" : "Edit History")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        if selectedType != nil { return qty > 0 }
        // custom requires a name and a valid integer unit
        return qty > 0 && !customName.trimmingCharacters(in: .whitespaces).isEmpty && Int(customUnit) != nil
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if let ev = existing {
            // EDIT existing
            ev.timestamp = date
            ev.quantity  = qty
            ev.note      = trimmedNote.isEmpty ? nil : trimmedNote

            if let t = selectedType {
                ev.type = t
                ev.typeNameSnapshot = t.name
                ev.unitCostRupeesSnapshot = t.costPerCigRupees
            } else {
                ev.type = nil
                ev.typeNameSnapshot = customName.trimmingCharacters(in: .whitespaces).isEmpty ? "Unknown" : customName
                ev.unitCostRupeesSnapshot = max(0, Int(customUnit) ?? ev.unitCostRupeesSnapshot)
            }
        } else {
            // ADD new
            if let t = selectedType {
                context.insert(SmokeEvent(timestamp: date, quantity: qty, type: t, note: trimmedNote.isEmpty ? nil : trimmedNote))
            } else {
                let unit = max(0, Int(customUnit) ?? 0)
                let name = customName.trimmingCharacters(in: .whitespaces).isEmpty ? "Unknown" : customName
                context.insert(SmokeEvent(timestamp: date, quantity: qty, typeNameSnapshot: name, unitCostRupeesSnapshot: unit, note: trimmedNote.isEmpty ? nil : trimmedNote))
            }
        }

        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        dismiss()
    }
}

