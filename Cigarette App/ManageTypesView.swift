import SwiftUI
import SwiftData

struct ManageTypesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CigType.name) private var types: [CigType]

    @State private var showNew = false
    @State private var confirmDelete: CigType?
    @State private var editing: CigType?   // which item is being edited

    var body: some View {
        List {
            ForEach(types) { t in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t.name).font(.headline)
                        Text("Pack \(t.packSize) • ₹\(t.packPriceRupees) • ₹\(t.costPerCigRupees)/cig")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("Common", isOn: Binding(get: { t.isCommon }, set: { t.isCommon = $0 }))
                        .labelsHidden()
                }
                .contentShape(Rectangle())          // make full row tappable
                .onTapGesture { editing = t }       // tap to edit
                .swipeActions(edge: .trailing) {
                    Button("Edit") { editing = t }
                    Button(role: .destructive) {
                        confirmDelete = t
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            // System "Edit" button deletes immediately (safe with .nullify history)
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
        .sheet(isPresented: $showNew) { NewTypeSheet() }             // Add new
        .sheet(item: $editing) { type in EditCigTypeSheet(type: type) } // Edit existing

        // Confirm before deleting via swipe action
        .alert(
            "Delete \(confirmDelete?.name ?? "this type")?",
            isPresented: Binding(
                get: { confirmDelete != nil },
                set: { if !$0 { confirmDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let t = confirmDelete {
                    // With .nullify on CigType.events:
                    // - The type is removed from your list (card disappears)
                    // - All past SmokeEvents KEEP their snapshot history
                    context.delete(t)
                }
                confirmDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("This removes the type from your list but keeps all past logs. Your history will remain intact.")
        }
    }
}

/* -------- Add sheet (unchanged) -------- */

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

/* -------- Edit sheet (you already had this) -------- */

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
