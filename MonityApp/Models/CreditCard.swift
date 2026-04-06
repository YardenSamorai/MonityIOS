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
