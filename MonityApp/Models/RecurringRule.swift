import Foundation

struct RecurringRule: Codable, Identifiable {
    let id: String
    var amount: Double
    var currency: String
    var type: Transaction.TransactionType
    var frequency: Frequency
    var startDate: String
    var endDate: String?
    var categoryId: Int?
    var category: TransactionCategory?
    var note: String
    var isActive: Bool

    enum Frequency: String, Codable, CaseIterable {
        case daily
        case weekly
        case monthly
        case yearly
    }

    enum CodingKeys: String, CodingKey {
        case id, amount, currency, type, frequency, startDate, endDate
        case categoryId, note, isActive
        case category = "Category"
    }
}

struct RecurringListResponse: Codable {
    let recurringRules: [RecurringRule]
}

struct RecurringSingleResponse: Codable {
    let recurringRule: RecurringRule
}
