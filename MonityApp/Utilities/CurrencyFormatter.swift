import Foundation

struct CurrencyHelper {
    static let currencySymbols: [String: String] = [
        "ILS": "₪",
        "USD": "$",
        "EUR": "€",
        "GBP": "£",
        "JPY": "¥",
        "CAD": "C$",
        "AUD": "A$",
        "CHF": "CHF",
    ]

    static func format(_ amount: Double, currency: String = "ILS") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2

        if let symbol = currencySymbols[currency] {
            formatter.currencySymbol = symbol
        }

        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(String(format: "%.2f", amount))"
    }

    static func symbol(for currency: String) -> String {
        currencySymbols[currency] ?? currency
    }
}
