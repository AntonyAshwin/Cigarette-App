import Foundation
import SwiftData

@Model
final class CigType {
    @Attribute(.unique) var name: String
    var packSize: Int
    var packPriceRupees: Int
    var notes: String?
    var isCommon: Bool
    var isArchived: Bool = false

    // On delete, set child.type = nil (don't crash, don't cascade)
    @Relationship(deleteRule: .nullify, inverse: \SmokeEvent.type)
    var events: [SmokeEvent] = []

    init(name: String,
         packSize: Int = 20,
         packPriceRupees: Int = 0,
         notes: String? = nil,
         isCommon: Bool = true,
         isArchived: Bool = false) {
        self.name = name
        self.packSize = max(1, packSize)
        self.packPriceRupees = max(0, packPriceRupees)
        self.notes = notes
        self.isCommon = isCommon
        self.isArchived = isArchived
    }

    var costPerCigRupees: Int {
        Int((Double(packPriceRupees) / Double(max(1, packSize))).rounded())
    }
}
