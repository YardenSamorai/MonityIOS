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

    nonisolated(unsafe) private static var formatterCache: [String: NumberFormatter] = [:]
    private static let cacheQueue = DispatchQueue(label: "com.monity.currencyFormatterCache")

    @MainActor
    static func defaultCurrency() -> String {
        AuthService.shared.currentUser?.preferredCurrency ?? "ILS"
    }

    @MainActor
    static func format(_ amount: Double, currency: String? = nil) -> String {
        let resolvedCurrency = currency ?? defaultCurrency()
        let locale = LanguageManager.shared.locale
        let cacheKey = "\(resolvedCurrency)_\(locale.identifier)"

        let formatter: NumberFormatter = cacheQueue.sync {
            if let cached = formatterCache[cacheKey] {
                return cached
            }
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.currencyCode = resolvedCurrency
            f.maximumFractionDigits = 2
            f.locale = locale
            if let symbol = currencySymbols[resolvedCurrency] {
                f.currencySymbol = symbol
            }
            formatterCache[cacheKey] = f
            return f
        }

        return formatter.string(from: NSNumber(value: amount)) ?? "\(resolvedCurrency) \(String(format: "%.2f", amount))"
    }

    static func symbol(for currency: String) -> String {
        currencySymbols[currency] ?? currency
    }

    static func clearCache() {
        cacheQueue.sync { formatterCache.removeAll() }
    }
}
