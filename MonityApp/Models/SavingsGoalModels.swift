import Foundation

struct SavingsGoal: Codable, Identifiable {
    let id: String
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var currency: String
    var targetDate: String?
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name, targetAmount, currentAmount, currency, targetDate, sortOrder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        targetAmount = try DecodingHelpers.decodeFlexibleDouble(c, forKey: .targetAmount)
        currentAmount = try DecodingHelpers.decodeFlexibleDouble(c, forKey: .currentAmount)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "ILS"
        targetDate = try c.decodeIfPresent(String.self, forKey: .targetDate)
        sortOrder = (try? c.decode(Int.self, forKey: .sortOrder)) ?? 0
    }
}

struct GoalsListResponse: Codable {
    let goals: [SavingsGoal]
}

struct GoalSingleResponse: Codable {
    let goal: SavingsGoal
}

struct CategoryRuleModel: Codable, Identifiable {
    let id: String
    var pattern: String
    var priority: Int
    var categoryId: Int
    let Category: TransactionCategory?

    enum CodingKeys: String, CodingKey {
        case id, pattern, priority, categoryId
        case Category
    }
}

struct CategoryRulesListResponse: Codable {
    let rules: [CategoryRuleModel]
}

struct CategoryRuleSingleResponse: Codable {
    let rule: CategoryRuleModel
}

struct TrashListResponse: Codable {
    let transactions: [Transaction]
}
