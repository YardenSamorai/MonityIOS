import Foundation

struct CurrencyInfo: Codable, Identifiable {
    var id: String { code }
    let code: String
    let name: String
    let symbol: String
}

struct CurrencyListResponse: Codable {
    let currencies: [CurrencyInfo]
}

struct ExchangeRateResponse: Codable {
    let base: String
    let rates: [String: Double]
    let source: String
}
