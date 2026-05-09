import Foundation

struct TransactionUser: Codable {
    let id: String
    let name: String
}

struct Transaction: Codable, Identifiable {
    let id: String
    var amount: Double
    var currency: String
    var type: TransactionType
    var note: String
    var date: String
    var categoryId: Int?
    var category: TransactionCategory?
    var recurringRuleId: String?
    var creditCardId: String?
    var isBilled: Bool?
    var installmentNumber: Int?
    var installmentCount: Int?
    var installmentGroupId: String?
    let createdAt: String?
    var user: TransactionUser?

    enum TransactionType: String, Codable, CaseIterable {
        case expense
        case income
    }

    enum CodingKeys: String, CodingKey {
        case id, amount, currency, type, note, date
        case categoryId, recurringRuleId, creditCardId, isBilled
        case installmentNumber, installmentCount, installmentGroupId, createdAt
        case category = "Category"
        case user = "User"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        amount = try DecodingHelpers.decodeFlexibleDouble(c, forKey: .amount)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "ILS"
        type = try c.decode(TransactionType.self, forKey: .type)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        date = try c.decode(String.self, forKey: .date)
        categoryId = try c.decodeIfPresent(Int.self, forKey: .categoryId)
        recurringRuleId = try c.decodeIfPresent(String.self, forKey: .recurringRuleId)
        creditCardId = try c.decodeIfPresent(String.self, forKey: .creditCardId)
        isBilled = try c.decodeIfPresent(Bool.self, forKey: .isBilled)
        installmentNumber = try c.decodeIfPresent(Int.self, forKey: .installmentNumber)
        installmentCount = try c.decodeIfPresent(Int.self, forKey: .installmentCount)
        installmentGroupId = try c.decodeIfPresent(String.self, forKey: .installmentGroupId)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        category = try c.decodeIfPresent(TransactionCategory.self, forKey: .category)
        user = try c.decodeIfPresent(TransactionUser.self, forKey: .user)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(amount, forKey: .amount)
        try c.encode(currency, forKey: .currency)
        try c.encode(type, forKey: .type)
        try c.encode(note, forKey: .note)
        try c.encode(date, forKey: .date)
        try c.encodeIfPresent(categoryId, forKey: .categoryId)
        try c.encodeIfPresent(recurringRuleId, forKey: .recurringRuleId)
        try c.encodeIfPresent(creditCardId, forKey: .creditCardId)
        try c.encodeIfPresent(isBilled, forKey: .isBilled)
        try c.encodeIfPresent(installmentNumber, forKey: .installmentNumber)
        try c.encodeIfPresent(installmentCount, forKey: .installmentCount)
        try c.encodeIfPresent(installmentGroupId, forKey: .installmentGroupId)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encodeIfPresent(user, forKey: .user)
    }
}

enum DecodingHelpers {
    static func decodeFlexibleDouble<K: CodingKey>(_ container: KeyedDecodingContainer<K>, forKey key: K) throws -> Double {
        if let d = try? container.decode(Double.self, forKey: key) { return d }
        if let s = try? container.decode(String.self, forKey: key), let d = Double(s) { return d }
        return 0
    }

    static func decodeFlexibleDoubleIfPresent<K: CodingKey>(_ container: KeyedDecodingContainer<K>, forKey key: K) throws -> Double? {
        if let d = try? container.decodeIfPresent(Double.self, forKey: key) { return d }
        if let s = try? container.decodeIfPresent(String.self, forKey: key) { return Double(s) }
        return nil
    }
}

struct TransactionCategory: Codable, Identifiable {
    let id: Int
    let name: String
    let nameHe: String?
    let icon: String
    let color: String

    var localizedName: String {
        let lang = UserDefaults.standard.string(forKey: "app_language") ?? "he"
        if lang == "he", let he = nameHe, !he.isEmpty {
            return he
        }
        return name
    }
}

struct TransactionListResponse: Codable {
    let transactions: [Transaction]
    let total: Int
    let page: Int
    let pages: Int
}

struct TransactionSingleResponse: Codable {
    let transaction: Transaction
}

struct TransactionSummary: Decodable {
    let income: Double
    let expense: Double
    let balance: Double
    let byCategory: [CategorySummary]

    private enum CodingKeys: String, CodingKey {
        case income, expense, balance, byCategory
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        income = try DecodingHelpers.decodeFlexibleDouble(c, forKey: .income)
        expense = try DecodingHelpers.decodeFlexibleDouble(c, forKey: .expense)
        balance = try DecodingHelpers.decodeFlexibleDouble(c, forKey: .balance)
        byCategory = try c.decodeIfPresent([CategorySummary].self, forKey: .byCategory) ?? []
    }
}

struct CategorySummary: Identifiable, Decodable {
    var id: Int { categoryId ?? 0 }
    let categoryId: Int?
    let totalAmount: Double
    let count: Int
    let Category: TransactionCategory?

    enum CodingKeys: String, CodingKey {
        case categoryId, total, count, Category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        categoryId = try container.decodeIfPresent(Int.self, forKey: .categoryId)
        Category = try container.decodeIfPresent(TransactionCategory.self, forKey: .Category)
        totalAmount = try DecodingHelpers.decodeFlexibleDouble(container, forKey: .total)

        if let num = try? container.decode(Int.self, forKey: .count) {
            count = num
        } else if let str = try? container.decode(String.self, forKey: .count) {
            count = Int(str) ?? 0
        } else {
            count = 0
        }
    }
}

