import SwiftUI
import SwiftData

struct ManageTypesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CigType.name) private var types: [CigType]

    @State private var showNew = false
    @State private var confirmDelete: CigType?   // <- for confirmation alert

    var body: some View {
        List {
            ForEach(types) { t in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t.name).font(.headline)
                        Text("Pack \(t.packSize) • ₹\(t.packPriceRupees) • ₹\(t.costPerCigRupees)/cig")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("Common", isOn: Binding(get: { t.isCommon }, set: { t.isCommon = $0 }))
                        .labelsHidden()
                }
                // Swipe-to-delete with confirm
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        confirmDelete = t
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            // EditButton (left) shows red minus controls; this uses onDelete
            .onDelete { idx in
                for i in idx { context.delete(types[i]) }
            }
        }
        .navigationTitle("Manage Cigs")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { EditButton() }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showNew = true } label: { Label("Add", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showNew) { NewTypeSheet() }
        // Confirm before deleting (shows count of history entries)
        .alert(
            "Delete \(confirmDelete?.name ?? "this type")?",
            isPresented: Binding(
                get: { confirmDelete != nil },
                set: { if !$0 { confirmDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let t = confirmDelete {
                    context.delete(t)   // Cascade will remove its SmokeEvents
                }
                confirmDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            if let t = confirmDelete {
                Text("This will remove all \(t.events.count) logged entries for \(t.name).")
            }
        }
    }
}


/* -------- Add sheet (you already had this) -------- */

struct NewTypeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var packSize = "20"
    @State private var packPrice = ""   // rupees only
    @State private var isCommon = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    TextField("Name", text: $name)
                    Toggle("Show in common list", isOn: $isCommon)
                }
                Section("Pack") {
                    TextField("Pack size", text: $packSize).keyboardType(.numberPad)
                    TextField("Pack price (₹, no decimals)", text: $packPrice).keyboardType(.numberPad)
                }
            }
            .navigationTitle("New Cigarette")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let size = Int(packSize) ?? 20
                        let price = Int(packPrice) ?? 0
                        let t = CigType(
                            name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Unnamed" : name,
                            packSize: max(1, size),
                            packPriceRupees: max(0, price),
                            notes: nil,
                            isCommon: isCommon
                        )
                        context.insert(t)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/* -------- Edit sheet (NEW) -------- */

struct EditCigTypeSheet: View {
    @Environment(\.dismiss) private var dismiss

    // Bind directly to your @Model object so edits persist automatically
    @Bindable var type: CigType

    @State private var packSizeText: String
    @State private var packPriceText: String

    init(type: CigType) {
        self._type = Bindable(type)
        _packSizeText = State(initialValue: String(type.packSize))
        _packPriceText = State(initialValue: String(type.packPriceRupees))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    TextField("Name", text: $type.name)
                    Toggle("Show in common list", isOn: $type.isCommon)
                }
                Section("Pack") {
                    TextField("Pack size", text: $packSizeText).keyboardType(.numberPad)
                    TextField("Pack price (₹, no decimals)", text: $packPriceText).keyboardType(.numberPad)
                }
            }
            .navigationTitle("Edit Cigarette")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        type.packSize = max(1, Int(packSizeText) ?? type.packSize)
                        type.packPriceRupees = max(0, Int(packPriceText) ?? type.packPriceRupees)
                        dismiss()
                    }
                }
            }
        }
    }
}
