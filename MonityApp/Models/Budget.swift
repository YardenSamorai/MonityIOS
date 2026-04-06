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
