import Foundation

enum RecurringScheduleHelper {
    /// Next occurrence strictly after `today` (start of day), matching dashboard semantics.
    static func nextExecutionDate(for rule: RecurringRule) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: rule.startDate) else { return nil }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        if start > today { return start }

        switch rule.frequency {
        case .daily:
            return cal.date(byAdding: .day, value: 1, to: today)

        case .weekly:
            let targetWeekday = cal.component(.weekday, from: start)
            var comps = DateComponents()
            comps.weekday = targetWeekday
            return cal.nextDate(after: today, matching: comps, matchingPolicy: .nextTime)

        case .monthly:
            let targetDay = cal.component(.day, from: start)
            let currentDay = cal.component(.day, from: today)
            var comps = cal.dateComponents([.year, .month], from: today)
            let lastDay = cal.range(of: .day, in: .month, for: today)?.count ?? 28
            comps.day = min(targetDay, lastDay)

            if currentDay >= min(targetDay, lastDay) {
                comps.month = (comps.month ?? 1) + 1
            }
            return cal.date(from: comps)

        case .yearly:
            let targetMonth = cal.component(.month, from: start)
            let targetDay = cal.component(.day, from: start)
            var comps = DateComponents()
            comps.year = cal.component(.year, from: today)
            comps.month = targetMonth
            comps.day = targetDay
            if let d = cal.date(from: comps), d <= today {
                comps.year = (comps.year ?? 2026) + 1
            }
            return cal.date(from: comps)
        }
    }
}
