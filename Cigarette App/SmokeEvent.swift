import Foundation
import SwiftData

@Model
final class SmokeEvent {
    var timestamp: Date
    var quantity: Int

    // Optional so events survive if the CigType is deleted
    @Relationship var type: CigType?

    // Snapshots (used when type is nil)
    var typeNameSnapshot: String
    var unitCostRupeesSnapshot: Int

    var note: String?

    init(timestamp: Date = .now, quantity: Int = 1, type: CigType, note: String? = nil) {
        self.timestamp = timestamp
        self.quantity = max(1, quantity)
        self.type = type
        self.typeNameSnapshot = type.name
        self.unitCostRupeesSnapshot = type.costPerCigRupees
        self.note = note
    }

    // Always works (even if type == nil)
    var costRupees: Int { quantity * unitCostRupeesSnapshot }

    // Convenience for UI
    var displayTypeName: String { type?.name ?? typeNameSnapshot }
}
