import Foundation

struct DashboardRecurringItem: Identifiable {
    let id: String
    let rule: RecurringRule
    let isPending: Bool
}

struct BalancePoint: Identifiable {
    let id = UUID()
    let date: Date
    let balance: Double
}

struct TransactionDateGroup: Identifiable {
    let id: String
    let dateString: String
    let date: Date
    let transactions: [TransactionWithBalance]
}

struct TransactionWithBalance: Identifiable {
    let id: String
    let transaction: Transaction
    let balanceAfter: Double
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var summary: TransactionSummary?
    @Published var recentTransactions: [Transaction] = []
    @Published var budgetStatuses: [BudgetStatus] = []
    @Published var creditCards: [CreditCard] = []
    @Published var recurringExpenses: [DashboardRecurringItem] = []
    @Published var recurringIncome: [DashboardRecurringItem] = []
    @Published var monthTransactions: [Transaction] = []
    @Published var balanceChartData: [BalancePoint] = []
    @Published var transactionGroups: [TransactionDateGroup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var totalCreditCardPending: Double {
        creditCards.reduce(0) { $0 + ($1.currentBalance ?? 0) }
    }

    var totalPendingExpenses: Double {
        recurringExpenses.filter { $0.isPending }.reduce(0) { $0 + $1.rule.amount }
    }

    var totalPendingIncome: Double {
        recurringIncome.filter { $0.isPending }.reduce(0) { $0 + $1.rule.amount }
    }

    var fixedExpensesDone: Double {
        recurringExpenses.filter { !$0.isPending }.reduce(0) { $0 + $1.rule.amount }
    }

    var fixedIncomeDone: Double {
        recurringIncome.filter { !$0.isPending }.reduce(0) { $0 + $1.rule.amount }
    }

    var variableExpenses: Double {
        max(0, (summary?.expense ?? 0) - fixedExpensesDone)
    }

    var variableIncome: Double {
        max(0, (summary?.income ?? 0) - fixedIncomeDone)
    }

    var availableToSpend: Double {
        let balance = summary?.balance ?? 0
        return balance - totalCreditCardPending - totalPendingExpenses
    }

    var projectedEndOfMonth: Double {
        let balance = summary?.balance ?? 0
        return balance - totalCreditCardPending - totalPendingExpenses + totalPendingIncome
    }

    func loadDashboard() async {
        isLoading = true
        errorMessage = nil

        let (from, to) = DateHelper.currentMonthRange()

        async let summaryTask = loadSummary(from: from, to: to)
        async let transactionsTask = loadRecentTransactions()
        async let budgetsTask = loadBudgets()
        async let cardsTask = loadCards()
        async let recurringTask = loadRecurring()

        let _ = await (summaryTask, transactionsTask, budgetsTask, cardsTask, recurringTask)

        isLoading = false

        syncToWidget()
        triggerNotifications()
    }

    private func syncToWidget() {
        let currency = AuthService.shared.currentUser?.preferredCurrency ?? "ILS"
        SharedDataManager.shared.save(
            balance: summary?.balance ?? 0,
            income: summary?.income ?? 0,
            expense: summary?.expense ?? 0,
            currency: currency
        )
    }

    private func triggerNotifications() {
        NotificationManager.shared.checkBudgetAlerts(budgets: budgetStatuses)
        NotificationManager.shared.scheduleCardReminders(cards: creditCards)
    }

    private func loadSummary(from: String, to: String) async {
        do {
            let s: TransactionSummary = try await APIClient.shared.request(
                endpoint: "/transactions/summary",
                queryItems: [
                    URLQueryItem(name: "from", value: from),
                    URLQueryItem(name: "to", value: to),
                ]
            )
            summary = s
        } catch {
            print("Summary error: \(error)")
        }
    }

    private func loadRecentTransactions() async {
        do {
            let t: TransactionListResponse = try await APIClient.shared.request(
                endpoint: "/transactions",
                queryItems: [URLQueryItem(name: "limit", value: "5")]
            )
            recentTransactions = t.transactions
        } catch {
            print("Transactions error: \(error)")
        }
    }

    private func loadBudgets() async {
        do {
            let b: BudgetStatusResponse = try await APIClient.shared.request(
                endpoint: "/budgets/status"
            )
            budgetStatuses = b.budgets
        } catch {
            print("Budgets error: \(error)")
        }
    }

    private func loadCards() async {
        do {
            let c: CreditCardListResponse = try await APIClient.shared.request(
                endpoint: "/credit-cards"
            )
            creditCards = c.creditCards.filter { $0.isActive }
        } catch {
            print("Cards error: \(error)")
        }
    }

    private func loadRecurring() async {
        do {
            let r: RecurringListResponse = try await APIClient.shared.request(
                endpoint: "/recurring"
            )
            let activeRules = r.recurringRules.filter { $0.isActive }
            recurringExpenses = activeRules
                .filter { $0.type == .expense }
                .map { DashboardRecurringItem(id: $0.id, rule: $0, isPending: isPendingThisMonth($0)) }
            recurringIncome = activeRules
                .filter { $0.type == .income }
                .map { DashboardRecurringItem(id: $0.id, rule: $0, isPending: isPendingThisMonth($0)) }
        } catch {
            print("Recurring error: \(error)")
        }
    }

    func loadMonthTransactions() async {
        let (from, to) = DateHelper.currentMonthRange()
        do {
            let response: TransactionListResponse = try await APIClient.shared.request(
                endpoint: "/transactions",
                queryItems: [
                    URLQueryItem(name: "from", value: from),
                    URLQueryItem(name: "to", value: to),
                    URLQueryItem(name: "limit", value: "500"),
                ]
            )
            monthTransactions = response.transactions
            computeBalanceData()
        } catch {
            print("Month transactions error: \(error)")
        }
    }

    private func computeBalanceData() {
        let currentBalance = summary?.balance ?? 0
        let sorted = monthTransactions.sorted { $0.date < $1.date }

        let totalNet = sorted.reduce(0.0) { acc, t in
            acc + (t.type == .income ? t.amount : -t.amount)
        }
        let startBalance = currentBalance - totalNet

        var running = startBalance
        var chartPoints: [BalancePoint] = []
        var transactionsWithBalance: [TransactionWithBalance] = []

        if let firstDate = sorted.first.flatMap({ DateHelper.fromAPIString($0.date) }) {
            chartPoints.append(BalancePoint(date: Calendar.current.date(byAdding: .day, value: -1, to: firstDate) ?? firstDate, balance: startBalance))
        }

        for t in sorted {
            let delta = t.type == .income ? t.amount : -t.amount
            running += delta
            transactionsWithBalance.append(TransactionWithBalance(id: t.id, transaction: t, balanceAfter: running))
            if let date = DateHelper.fromAPIString(t.date) {
                chartPoints.append(BalancePoint(date: date, balance: running))
            }
        }

        balanceChartData = chartPoints

        let grouped = Dictionary(grouping: transactionsWithBalance.reversed()) { $0.transaction.date }
        transactionGroups = grouped.map { key, value in
            TransactionDateGroup(
                id: key,
                dateString: key,
                date: DateHelper.fromAPIString(key) ?? Date(),
                transactions: value
            )
        }
        .sorted { $0.date > $1.date }
    }

    private func isPendingThisMonth(_ rule: RecurringRule) -> Bool {
        guard let next = nextExecutionDate(for: rule) else { return false }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let currentMonth = cal.component(.month, from: today)
        let currentYear = cal.component(.year, from: today)
        let nextMonth = cal.component(.month, from: next)
        let nextYear = cal.component(.year, from: next)

        return next > today && nextMonth == currentMonth && nextYear == currentYear
    }

    private func nextExecutionDate(for rule: RecurringRule) -> Date? {
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
