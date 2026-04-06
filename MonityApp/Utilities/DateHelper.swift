import Foundation

struct DateHelper {
    static let apiFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static var displayFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        let lang = UserDefaults.standard.string(forKey: "app_language") ?? "he"
        f.locale = Locale(identifier: lang)
        return f
    }

    static func toAPIString(_ date: Date) -> String {
        apiFormatter.string(from: date)
    }

    static func fromAPIString(_ string: String) -> Date? {
        apiFormatter.date(from: string)
    }

    static func display(_ dateString: String) -> String {
        guard let date = fromAPIString(dateString) else { return dateString }
        return displayFormatter.string(from: date)
    }

    static func currentMonthRange() -> (from: String, to: String) {
        let now = Date()
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
        return (toAPIString(start), toAPIString(end))
    }

    static func monthName(from dateString: String) -> String {
        guard let date = fromAPIString(dateString) else { return "" }
        let lang = UserDefaults.standard.string(forKey: "app_language") ?? "he"
        let f = DateFormatter()
        f.locale = Locale(identifier: lang)
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}
