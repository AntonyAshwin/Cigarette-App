import Foundation
import SwiftData

@Model
final class SmokeEvent {
    var timestamp: Date
    var quantity: Int

    // Child → parent inverse
    @Relationship(inverse: \CigType.events)
    var type: CigType

    var note: String?

    init(timestamp: Date = .now, quantity: Int = 1, type: CigType, note: String? = nil) {
        self.timestamp = timestamp
        self.quantity = max(1, quantity)
        self.type = type
        self.note = note
    }

    // <- Add this line
    var costRupees: Int { quantity * type.costPerCigRupees }
}
