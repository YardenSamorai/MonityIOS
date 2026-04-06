import Foundation

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
    let createdAt: String?

    enum TransactionType: String, Codable, CaseIterable {
        case expense
        case income
    }

    enum CodingKeys: String, CodingKey {
        case id, amount, currency, type, note, date
        case categoryId, recurringRuleId, creditCardId, isBilled, createdAt
        case category = "Category"
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

        if let num = try? container.decode(Double.self, forKey: .total) {
            totalAmount = num
        } else if let str = try? container.decode(String.self, forKey: .total) {
            totalAmount = Double(str) ?? 0
        } else {
            totalAmount = 0
        }

        if let num = try? container.decode(Int.self, forKey: .count) {
            count = num
        } else if let str = try? container.decode(String.self, forKey: .count) {
            count = Int(str) ?? 0
        } else {
            count = 0
        }
    }
}
