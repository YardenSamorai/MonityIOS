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
            let val = UserDefaults.standard.integer(forKey: "daily_reminder_hour")
            return val == 0 ? 21 : val
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "daily_reminder_hour")
            if dailyReminderEnabled { scheduleDailyReminder() }
        }
    }

    var budgetAlertsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "budget_alerts_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "budget_alerts_enabled") }
    }

    var cardReminderEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "card_reminder_enabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "card_reminder_enabled")
            if !newValue { cancelCardReminders() }
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

        for budget in budgets {
            guard budget.limitAmount > 0 else { continue }
            let usage = budget.spent / budget.limitAmount
            if usage >= 0.8 {
                sendBudgetAlert(budget: budget, usage: usage)
            }
        }
    }

    private func sendBudgetAlert(budget: BudgetStatus, usage: Double) {
        let alertKey = "budget_alert_\(budget.id)_\(DateHelper.currentMonthRange().from)"
        guard !UserDefaults.standard.bool(forKey: alertKey) else { return }

        let content = UNMutableNotificationContent()
        content.title = L("notif_budget_title")
        let pct = Int(usage * 100)
        let catName = budget.category?.localizedName ?? "Budget"
        content.body = String(format: L("notif_budget_body"), catName, pct)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "budget_\(budget.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
        UserDefaults.standard.set(true, forKey: alertKey)
    }

    // MARK: - Credit Card Reminders

    func scheduleCardReminders(cards: [CreditCard]) {
        guard cardReminderEnabled else { return }
        cancelCardReminders()

        for card in cards {
            let billingDay = card.billingDay
            let reminderDay = billingDay <= 2 ? billingDay + 28 : billingDay - 2

            let content = UNMutableNotificationContent()
            content.title = L("notif_card_title")
            content.body = String(format: L("notif_card_body"), card.name)
            content.sound = .default

            var components = DateComponents()
            components.day = reminderDay
            components.hour = 10

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "card_\(card.id)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    func cancelCardReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let cardIDs = requests.filter { $0.identifier.hasPrefix("card_") }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: cardIDs)
        }
    }
}
