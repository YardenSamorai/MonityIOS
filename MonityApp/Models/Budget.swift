import Foundation

struct Budget: Codable, Identifiable {
    let id: String
    var limitAmount: StringOrDouble
    var period: BudgetPeriod
    var categoryId: Int?
    var Category: TransactionCategory?

    enum BudgetPeriod: String, Codable, CaseIterable {
        case weekly
        case monthly
        case yearly
    }

    var limit: Double {
        limitAmount.doubleValue
    }
}

enum StringOrDouble: Codable {
    case string(String)
    case double(Double)

    var doubleValue: Double {
        switch self {
        case .string(let s): return Double(s) ?? 0
        case .double(let d): return d
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else {
            self = .double(0)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .double(let d): try container.encode(d)
        }
    }
}

struct BudgetStatus: Codable, Identifiable {
    let id: String
    let category: TransactionCategory?
    let limitAmount: Double
    let spent: Double
    let remaining: Double
    let percentage: Double
    let period: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, category, limitAmount, spent, remaining, percentage, period, status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        category = try c.decodeIfPresent(TransactionCategory.self, forKey: .category)
        limitAmount = try DecodingHelpers.decodeFlexibleDouble(c, forKey: .limitAmount)
        spent = try DecodingHelpers.decodeFlexibleDouble(c, forKey: .spent)
        remaining = try DecodingHelpers.decodeFlexibleDouble(c, forKey: .remaining)
        percentage = try DecodingHelpers.decodeFlexibleDouble(c, forKey: .percentage)
        period = try c.decode(String.self, forKey: .period)
        status = try c.decode(String.self, forKey: .status)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encode(limitAmount, forKey: .limitAmount)
        try c.encode(spent, forKey: .spent)
        try c.encode(remaining, forKey: .remaining)
        try c.encode(percentage, forKey: .percentage)
        try c.encode(period, forKey: .period)
        try c.encode(status, forKey: .status)
    }
}

struct BudgetListResponse: Codable {
    let budgets: [Budget]
}

struct BudgetStatusResponse: Codable {
    let budgets: [BudgetStatus]
}

struct BudgetSingleResponse: Codable {
    let budget: Budget
}
