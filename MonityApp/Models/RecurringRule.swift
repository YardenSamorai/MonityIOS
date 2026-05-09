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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        amount = try DecodingHelpers.decodeFlexibleDouble(c, forKey: .amount)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "ILS"
        type = try c.decode(Transaction.TransactionType.self, forKey: .type)
        frequency = try c.decode(Frequency.self, forKey: .frequency)
        startDate = try c.decode(String.self, forKey: .startDate)
        endDate = try c.decodeIfPresent(String.self, forKey: .endDate)
        categoryId = try c.decodeIfPresent(Int.self, forKey: .categoryId)
        category = try c.decodeIfPresent(TransactionCategory.self, forKey: .category)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(amount, forKey: .amount)
        try c.encode(currency, forKey: .currency)
        try c.encode(type, forKey: .type)
        try c.encode(frequency, forKey: .frequency)
        try c.encode(startDate, forKey: .startDate)
        try c.encodeIfPresent(endDate, forKey: .endDate)
        try c.encodeIfPresent(categoryId, forKey: .categoryId)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encode(note, forKey: .note)
        try c.encode(isActive, forKey: .isActive)
    }
}

struct RecurringListResponse: Codable {
    let recurringRules: [RecurringRule]
}

struct RecurringSingleResponse: Codable {
    let recurringRule: RecurringRule
}
