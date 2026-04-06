import Foundation
import WidgetKit

struct SharedFinancialData: Codable {
    let balance: Double
    let income: Double
    let expense: Double
    let currency: String
    let month: String
    let lastUpdated: Date
}

final class SharedDataManager {
    static let shared = SharedDataManager()
    static let appGroupID = "group.com.monityIOS.app"
    static let dataKey = "widget_financial_data"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: SharedDataManager.appGroupID)
    }

    func save(balance: Double, income: Double, expense: Double, currency: String) {
        let (from, _) = DateHelper.currentMonthRange()
        let data = SharedFinancialData(
            balance: balance,
            income: income,
            expense: expense,
            currency: currency,
            month: DateHelper.monthName(from: from),
            lastUpdated: Date()
        )

        guard let encoded = try? JSONEncoder().encode(data) else { return }

        let defaults = sharedDefaults ?? UserDefaults.standard
        defaults.set(encoded, forKey: SharedDataManager.dataKey)

        WidgetCenter.shared.reloadAllTimelines()
    }

    func load() -> SharedFinancialData? {
        let defaults = sharedDefaults ?? UserDefaults.standard
        guard let data = defaults.data(forKey: SharedDataManager.dataKey) else { return nil }
        return try? JSONDecoder().decode(SharedFinancialData.self, from: data)
    }
}
