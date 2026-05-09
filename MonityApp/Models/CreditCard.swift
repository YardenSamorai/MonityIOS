import Foundation

struct CreditCard: Codable, Identifiable {
    let id: String
    var name: String
    var lastFourDigits: String
    var billingDay: Int
    var creditLimit: Double?
    var color: String
    var isActive: Bool
    var currentBalance: Double?
    var lastBilledAt: String?
    var sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, lastFourDigits, billingDay, creditLimit, color, isActive
        case currentBalance, lastBilledAt, sortOrder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        lastFourDigits = try c.decodeIfPresent(String.self, forKey: .lastFourDigits) ?? ""
        billingDay = try c.decode(Int.self, forKey: .billingDay)
        creditLimit = try DecodingHelpers.decodeFlexibleDoubleIfPresent(c, forKey: .creditLimit)
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? "#6C63FF"
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        currentBalance = try DecodingHelpers.decodeFlexibleDoubleIfPresent(c, forKey: .currentBalance)
        lastBilledAt = try c.decodeIfPresent(String.self, forKey: .lastBilledAt)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(lastFourDigits, forKey: .lastFourDigits)
        try c.encode(billingDay, forKey: .billingDay)
        try c.encodeIfPresent(creditLimit, forKey: .creditLimit)
        try c.encode(color, forKey: .color)
        try c.encode(isActive, forKey: .isActive)
        try c.encodeIfPresent(currentBalance, forKey: .currentBalance)
        try c.encodeIfPresent(lastBilledAt, forKey: .lastBilledAt)
        try c.encodeIfPresent(sortOrder, forKey: .sortOrder)
    }

    init(id: String, name: String, lastFourDigits: String, billingDay: Int, creditLimit: Double?, color: String, isActive: Bool, currentBalance: Double?, lastBilledAt: String?, sortOrder: Int?) {
        self.id = id
        self.name = name
        self.lastFourDigits = lastFourDigits
        self.billingDay = billingDay
        self.creditLimit = creditLimit
        self.color = color
        self.isActive = isActive
        self.currentBalance = currentBalance
        self.lastBilledAt = lastBilledAt
        self.sortOrder = sortOrder
    }
}

struct CreditCardListResponse: Codable {
    let creditCards: [CreditCard]
}

struct CreditCardSingleResponse: Codable {
    let creditCard: CreditCard
}

struct CreditCardDetailResponse: Codable {
    let creditCard: CreditCard
    let transactions: [Transaction]
}

struct CreditCardBillResponse: Codable {
    let charged: Double
}

struct CreditCardHistorySummary: Codable {
    let totalExpenses: Double
    let totalCredits: Double
    let netCharge: Double
}

struct CreditCardHistoryResponse: Codable {
    let month: String
    let transactions: [Transaction]
    let summary: CreditCardHistorySummary
    let availableMonths: [String]
}
