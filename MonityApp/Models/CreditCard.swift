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
