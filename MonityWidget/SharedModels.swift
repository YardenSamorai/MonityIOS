import Foundation

struct WidgetFinancialData: Codable {
    let balance: Double
    let income: Double
    let expense: Double
    let currency: String
    let month: String
    let lastUpdated: Date
}

struct WidgetDataLoader {
    static let appGroupID = "group.com.monityIOS.app"
    static let dataKey = "widget_financial_data"

    static func load() -> WidgetFinancialData? {
        let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
        guard let data = defaults.data(forKey: dataKey) else { return nil }
        return try? JSONDecoder().decode(WidgetFinancialData.self, from: data)
    }

    static func formatCurrency(_ amount: Double, currency: String) -> String {
        let symbols: [String: String] = [
            "ILS": "₪", "USD": "$", "EUR": "€", "GBP": "£",
            "JPY": "¥", "CAD": "C$", "AUD": "A$", "CHF": "CHF"
        ]
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        if let symbol = symbols[currency] {
            formatter.currencySymbol = symbol
        }
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(Int(amount))"
    }
}
