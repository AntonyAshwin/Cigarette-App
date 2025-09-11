import SwiftUI
import SwiftData

struct ManageTypesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \CigType.name) private var types: [CigType]

    @State private var showNew = false

    var body: some View {
        NavigationStack {
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
                }
                .onDelete { idx in for i in idx { context.delete(types[i]) } }
            }
            .navigationTitle("Manage Cigs")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showNew = true } label: { Label("Add", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $showNew) { NewTypeSheet() }
        }
    }
}

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
                    TextField("Pack size", text: $packSize)
                        .keyboardType(.numberPad)
                    TextField("Pack price (₹, no decimals)", text: $packPrice)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("New Cigarette")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let size = Int(packSize) ?? 20
                        let price = Int(packPrice) ?? 0
                        let t = CigType(name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Unnamed" : name,
                                        packSize: max(1, size),
                                        packPriceRupees: max(0, price),
                                        notes: nil,
                                        isCommon: isCommon)
                        context.insert(t)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
