import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    var dailyReminderEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "daily_reminder_enabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "daily_reminder_enabled")
            if newValue {
                scheduleDailyReminder()
            } else {
                cancelDailyReminder()
            }
        }
    }

    var dailyReminderHour: Int {
        get {
            if UserDefaults.standard.object(forKey: "daily_reminder_hour") == nil {
                return 21
            }
            return UserDefaults.standard.integer(forKey: "daily_reminder_hour")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "daily_reminder_hour")
            if dailyReminderEnabled { scheduleDailyReminder() }
            Task { await refreshCardAndRecurringFromServer() }
        }
    }

    /// When spending reaches this % of the budget limit, a one-time alert is sent (per category per month).
    var budgetAlertThresholdPercent: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: "budget_alert_threshold_pct")
            if v == 0 { return 80 }
            if [80, 90, 100].contains(v) { return v }
            return 80
        }
        set {
            let clamped = min(100, max(50, newValue))
            UserDefaults.standard.set(clamped, forKey: "budget_alert_threshold_pct")
        }
    }

    var budgetAlertsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "budget_alerts_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "budget_alerts_enabled") }
    }

    /// Days before the billing date to remind (1 = day before, 2 = two days before, …).
    var cardReminderDaysBefore: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: "card_reminder_days_before")
            if v == 0 { return 2 }
            return min(7, max(1, v))
        }
        set {
            UserDefaults.standard.set(min(7, max(1, newValue)), forKey: "card_reminder_days_before")
            Task { await refreshCardAndRecurringFromServer() }
        }
    }

    var cardReminderEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "card_reminder_enabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "card_reminder_enabled")
            if newValue {
                Task { await refreshCardAndRecurringFromServer() }
            } else {
                cancelCardReminders()
            }
        }
    }

    /// Notify the calendar day before a recurring income/expense is due.
    var recurringDueReminderEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "recurring_due_reminder_enabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "recurring_due_reminder_enabled")
            if newValue {
                Task { await refreshCardAndRecurringFromServer() }
            } else {
                cancelRecurringDueReminders()
            }
        }
    }

    private init() {
        Task { await checkAuthorization() }
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            isAuthorized = granted
            return granted
        } catch {
            return false
        }
    }

    func checkAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    /// Reschedules credit-card and recurring notifications from the server (after toggles or time changes).
    func refreshCardAndRecurringFromServer() async {
        await checkAuthorization()
        guard isAuthorized else { return }

        if cardReminderEnabled {
            do {
                let c: CreditCardListResponse = try await APIClient.shared.request(endpoint: "/credit-cards")
                scheduleCardReminders(cards: c.creditCards.filter { $0.isActive })
            } catch {
                print("Card notification refresh error: \(error)")
            }
        } else {
            cancelCardReminders()
        }

        if recurringDueReminderEnabled {
            do {
                let r: RecurringListResponse = try await APIClient.shared.request(endpoint: "/recurring")
                scheduleRecurringDueReminders(rules: r.recurringRules.filter { $0.isActive })
            } catch {
                print("Recurring notification refresh error: \(error)")
            }
        } else {
            cancelRecurringDueReminders()
        }
    }

    // MARK: - Daily Reminder

    func scheduleDailyReminder() {
        cancelDailyReminder()

        let content = UNMutableNotificationContent()
        content.title = L("notif_daily_title")
        content.body = L("notif_daily_body")
        content.sound = .default

        var components = DateComponents()
        components.hour = dailyReminderHour
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
    }

    // MARK: - Budget Alerts

    func checkBudgetAlerts(budgets: [BudgetStatus]) {
        guard budgetAlertsEnabled else { return }

        let threshold = Double(budgetAlertThresholdPercent) / 100.0
        for budget in budgets {
            guard budget.limitAmount > 0 else { continue }
            let usage = budget.spent / budget.limitAmount
            if usage >= threshold {
                sendBudgetAlert(budget: budget, usage: usage, thresholdPercent: budgetAlertThresholdPercent)
            }
        }
    }

    private func sendBudgetAlert(budget: BudgetStatus, usage: Double, thresholdPercent: Int) {
        let monthlyKey = DateHelper.currentMonthRange().from
        let alertKey = "budget_alert_\(budget.id)_\(monthlyKey)_t\(thresholdPercent)"
        guard !UserDefaults.standard.bool(forKey: alertKey) else { return }

        let content = UNMutableNotificationContent()
        content.title = L("notif_budget_title")
        let pct = Int(usage * 100)
        let catName = budget.category?.localizedName ?? "Budget"
        content.body = String(format: L("notif_budget_body"), catName, pct)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "budget_\(budget.id)_\(thresholdPercent)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
        UserDefaults.standard.set(true, forKey: alertKey)
    }

    // MARK: - Credit Card Reminders

    func scheduleCardReminders(cards: [CreditCard]) {
        guard cardReminderEnabled else { return }

        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let cardIDs = requests.filter { $0.identifier.hasPrefix("card_") }.map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: cardIDs)

            Task { @MainActor in
                self.addCardNotificationRequests(cards: cards)
            }
        }
    }

    private func addCardNotificationRequests(cards: [CreditCard]) {
        let calendar = Calendar.current
        let now = Date()
        let daysBefore = cardReminderDaysBefore
        let hour = dailyReminderHour

        for card in cards {
            var billing = nextBillingDate(billingDay: card.billingDay, from: now, calendar: calendar)
            for offset in 0..<3 {
                guard let billingDate = billing,
                      let reminderDate = calendar.date(byAdding: .day, value: -daysBefore, to: billingDate)
                else { continue }

                let content = UNMutableNotificationContent()
                content.title = L("notif_card_title")
                content.body = String(format: L("notif_card_body"), card.name, cardReminderDaysBefore)
                content.sound = .default

                var components = calendar.dateComponents([.year, .month, .day], from: reminderDate)
                components.hour = hour
                components.minute = 0

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "card_\(card.id)_m\(offset)",
                    content: content,
                    trigger: trigger
                )
                UNUserNotificationCenter.current().add(request)

                billing = calendar.date(byAdding: .month, value: 1, to: billingDate)
            }
        }
    }

    private func nextBillingDate(billingDay: Int, from date: Date, calendar: Calendar) -> Date? {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let today = components.day else { return nil }

        var targetMonth = month
        var targetYear = year
        if today >= billingDay {
            targetMonth += 1
            if targetMonth > 12 {
                targetMonth = 1
                targetYear += 1
            }
        }

        let range = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: targetYear, month: targetMonth, day: 1)) ?? Date()) ?? 28..<29
        let lastDay = range.upperBound - 1
        let day = min(billingDay, lastDay)

        return calendar.date(from: DateComponents(year: targetYear, month: targetMonth, day: day))
    }

    func cancelCardReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let cardIDs = requests.filter { $0.identifier.hasPrefix("card_") }.map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: cardIDs)
        }
    }

    // MARK: - Recurring (day before due)

    func scheduleRecurringDueReminders(rules: [RecurringRule]) {
        guard recurringDueReminderEnabled else { return }

        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix("recurring_") }.map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)

            Task { @MainActor in
                self.addRecurringNotificationRequests(rules: rules)
            }
        }
    }

    private func addRecurringNotificationRequests(rules: [RecurringRule]) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let hour = dailyReminderHour

        for rule in rules where rule.isActive {
            guard let nextRaw = RecurringScheduleHelper.nextExecutionDate(for: rule) else { continue }
            let nextDueStart = cal.startOfDay(for: nextRaw)
            guard let reminderDay = cal.date(byAdding: .day, value: -1, to: nextDueStart) else { continue }
            let reminderStart = cal.startOfDay(for: reminderDay)
            if reminderStart < today { continue }

            var comps = cal.dateComponents([.year, .month, .day], from: reminderStart)
            comps.hour = hour
            comps.minute = 0
            guard let y = comps.year, let mo = comps.month, let d = comps.day else { continue }

            let content = UNMutableNotificationContent()
            content.title = L("notif_recurring_title")
            let label = rule.note.isEmpty ? (rule.category?.localizedName ?? L("recurring_transactions")) : rule.note
            content.body = String(format: L("notif_recurring_body"), label)
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id = "recurring_\(rule.id)_\(y)\(mo)\(d)"
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    func cancelRecurringDueReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix("recurring_") }.map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}
