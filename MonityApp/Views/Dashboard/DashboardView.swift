import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showAddTransaction = false
    @State private var addButtonRotation: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    heroCard

                    availableToSpendCard

                    incomeExpenseRow

                    if !viewModel.creditCards.isEmpty {
                        creditCardsStrip
                    }

                    if !viewModel.recurringExpenses.isEmpty {
                        recurringExpensesSection
                    }

                    if !viewModel.recurringIncome.isEmpty {
                        recurringIncomeSection
                    }

                    if !viewModel.budgetStatuses.isEmpty {
                        budgetSection
                    }

                    recentTransactionsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .navigationTitle(greetingText)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            addButtonRotation += 90
                        }
                        showAddTransaction = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.primaryGradient)
                            .clipShape(Circle())
                            .rotationEffect(.degrees(addButtonRotation))
                            .shadow(color: AppTheme.accent.opacity(0.3), radius: 8, y: 4)
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView {
                    Task { await viewModel.loadDashboard() }
                }
            }
            .refreshable { await viewModel.loadDashboard() }
            .task {
                await viewModel.loadDashboard()
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        if hour < 12 { greeting = L("good_morning") }
        else if hour < 17 { greeting = L("good_afternoon") }
        else { greeting = L("good_evening") }

        if let name = authService.currentUser?.name.split(separator: " ").first {
            return "\(greeting), \(name)"
        }
        return greeting
    }

    // MARK: - Hero Card (Balance)

    private var heroCard: some View {
        NavigationLink {
            BalanceDetailView(viewModel: viewModel)
        } label: {
            VStack(spacing: 8) {
                Text("balance")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))

                Text(CurrencyHelper.format(viewModel.summary?.balance ?? 0))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                let (from, _) = DateHelper.currentMonthRange()
                HStack(spacing: 6) {
                    Text(DateHelper.monthName(from: from))
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppTheme.primaryGradient)
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 20, y: 10)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Available to Spend

    private var availableToSpendCard: some View {
        SolidCard {
            VStack(spacing: 14) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "shield.checkered")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(statusColor)
                        Text("available_to_spend")
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    Text(statusText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor)
                        .clipShape(Capsule())
                }

                Text(CurrencyHelper.format(viewModel.availableToSpend))
                    .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(viewModel.availableToSpend >= 0 ? AppTheme.income : .red)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    if viewModel.totalCreditCardPending > 0 {
                        breakdownRow(
                            icon: "creditcard.fill",
                            label: "pending_card_charges",
                            amount: -viewModel.totalCreditCardPending,
                            color: .orange
                        )
                    }
                    if viewModel.totalPendingExpenses > 0 {
                        breakdownRow(
                            icon: "arrow.triangle.2.circlepath",
                            label: "upcoming_fixed_expenses",
                            amount: -viewModel.totalPendingExpenses,
                            color: AppTheme.expense
                        )
                    }
                    if viewModel.totalPendingIncome > 0 {
                        breakdownRow(
                            icon: "arrow.down.circle.fill",
                            label: "expected_income",
                            amount: viewModel.totalPendingIncome,
                            color: AppTheme.income
                        )
                    }
                }

                if viewModel.totalCreditCardPending > 0 || viewModel.totalPendingExpenses > 0 || viewModel.totalPendingIncome > 0 {
                    Divider()

                    HStack {
                        Image(systemName: "chart.line.text.clipboard")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("projected_end_of_month")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(CurrencyHelper.format(viewModel.projectedEndOfMonth))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundColor(viewModel.projectedEndOfMonth >= 0 ? .primary : .red)
                    }
                }
            }
            .padding(18)
        }
    }

    private func breakdownRow(icon: String, label: LocalizedStringKey, amount: Double, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text((amount >= 0 ? "+" : "") + CurrencyHelper.format(abs(amount)))
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(amount >= 0 ? AppTheme.income : color)
        }
    }

    private var statusColor: Color {
        let available = viewModel.availableToSpend
        if available < 0 { return .red }
        if available < (viewModel.summary?.income ?? 0) * 0.1 { return .orange }
        return AppTheme.income
    }

    private var statusText: String {
        let available = viewModel.availableToSpend
        if available < 0 { return L("status_overdraft") }
        if available < (viewModel.summary?.income ?? 0) * 0.1 { return L("status_tight") }
        return L("status_good")
    }

    // MARK: - Income / Expense Row

    private var incomeExpenseRow: some View {
        HStack(spacing: 14) {
            summaryCard(
                title: "expenses",
                total: viewModel.summary?.expense ?? 0,
                fixedAmount: viewModel.fixedExpensesDone,
                variableAmount: viewModel.variableExpenses,
                fixedLabel: "fixed_short",
                variableLabel: "variable_short",
                icon: "arrow.up.right",
                color: AppTheme.expense,
                gradient: AppTheme.expenseGradient
            )
            .cardPressEffect()

            summaryCard(
                title: "income",
                total: viewModel.summary?.income ?? 0,
                fixedAmount: viewModel.fixedIncomeDone,
                variableAmount: viewModel.variableIncome,
                fixedLabel: "fixed_short",
                variableLabel: "variable_short",
                icon: "arrow.down.left",
                color: AppTheme.income,
                gradient: AppTheme.incomeGradient
            )
            .cardPressEffect()
        }
    }

    private func summaryCard(
        title: LocalizedStringKey, total: Double,
        fixedAmount: Double, variableAmount: Double,
        fixedLabel: LocalizedStringKey, variableLabel: LocalizedStringKey,
        icon: String, color: Color, gradient: LinearGradient
    ) -> some View {
        SolidCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Spacer()
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(CurrencyHelper.format(total))
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if fixedAmount > 0 || variableAmount > 0 {
                    VStack(spacing: 4) {
                        if fixedAmount > 0 {
                            HStack(spacing: 4) {
                                Circle().fill(color.opacity(0.7)).frame(width: 6, height: 6)
                                Text(fixedLabel)
                                    .font(.system(size: 10).weight(.medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(CurrencyHelper.format(fixedAmount))
                                    .font(.system(size: 10).weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if variableAmount > 0 {
                            HStack(spacing: 4) {
                                Circle().fill(color.opacity(0.35)).frame(width: 6, height: 6)
                                Text(variableLabel)
                                    .font(.system(size: 10).weight(.medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(CurrencyHelper.format(variableAmount))
                                    .font(.system(size: 10).weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Credit Cards Strip

    private var creditCardsStrip: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("credit_cards")
                    .font(.title3.weight(.semibold))
                Spacer()
                NavigationLink {
                    CreditCardListView()
                } label: {
                    Text("see_all")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.creditCards) { card in
                        NavigationLink {
                            CreditCardDetailView(cardId: card.id)
                        } label: {
                            miniCreditCard(card)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func miniCreditCard(_ card: CreditCard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(card.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                if !card.lastFourDigits.isEmpty {
                    Text("•\(card.lastFourDigits)")
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Spacer()

            Text(CurrencyHelper.format(card.currentBalance ?? 0))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)

            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 8))
                Text("\(L("billing_day")) \(card.billingDay)")
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(.white.opacity(0.7))
        }
        .frame(width: 160, height: 100)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: card.color), Color(hex: card.color).opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
    }

    // MARK: - Recurring Expenses

    private var recurringExpensesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("fixed_expenses_title")
                .font(.title3.weight(.semibold))

            SolidCard {
                VStack(spacing: 0) {
                    let items = Array(viewModel.recurringExpenses.prefix(5))
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        recurringRow(item: item)

                        if index < items.count - 1 {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recurring Income

    private var recurringIncomeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("fixed_income_title")
                .font(.title3.weight(.semibold))

            SolidCard {
                VStack(spacing: 0) {
                    let items = Array(viewModel.recurringIncome.prefix(5))
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        recurringRow(item: item)

                        if index < items.count - 1 {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
            }
        }
    }

    private func recurringRow(item: DashboardRecurringItem) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Text(item.rule.category?.icon ?? "💰")
                    .font(.title3)
                    .frame(width: 40, height: 40)
                    .background(
                        item.rule.type == .income
                            ? AppTheme.income.opacity(0.12)
                            : AppTheme.expense.opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                if !item.isPending {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.income)
                        .background(Circle().fill(Color(.systemBackground)).frame(width: 12, height: 12))
                        .offset(x: 4, y: 4)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.rule.category?.localizedName ?? item.rule.note)
                    .font(.caption.weight(.semibold))
                Text(item.isPending ? L("status_pending") : L("status_done"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(item.isPending ? .orange : AppTheme.income)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text((item.rule.type == .income ? "+" : "-") + CurrencyHelper.format(item.rule.amount, currency: item.rule.currency))
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(item.rule.type == .income ? AppTheme.income : AppTheme.expense)

                Text(LocalizedStringKey(item.rule.frequency.rawValue))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .opacity(item.isPending ? 1 : 0.6)
    }

    // MARK: - Budget Section

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("budget_status")
                .font(.title3.weight(.semibold))

            ForEach(viewModel.budgetStatuses) { budget in
                BudgetProgressView(budget: budget)
            }
        }
    }

    // MARK: - Recent Transactions

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("recent_transactions")
                    .font(.title3.weight(.semibold))
                Spacer()
                NavigationLink {
                    TransactionListView()
                } label: {
                    Text("see_all")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            if viewModel.recentTransactions.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    icon: "tray",
                    title: "no_transactions",
                    message: "add_first_transaction"
                )
            } else {
                SolidCard {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.recentTransactions.enumerated()), id: \.element.id) { index, transaction in
                            TransactionRowView(transaction: transaction)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)

                            if index < viewModel.recentTransactions.count - 1 {
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                }
            }
        }
    }
}
