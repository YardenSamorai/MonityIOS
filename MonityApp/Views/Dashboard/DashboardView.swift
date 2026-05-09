import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showAddTransaction = false
    @State private var appeared = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        topGreeting
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : -8)

                        heroBalanceCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)

                        availableToSpendCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 16)

                        incomeExpenseRow
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)

                        if !viewModel.creditCards.isEmpty {
                            creditCardsSection
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 24)
                        }

                        if !viewModel.budgetStatuses.isEmpty {
                            budgetSection
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 24)
                        }

                        if !viewModel.recurringIncome.isEmpty {
                            recurringSection(
                                title: "fixed_income_title",
                                icon: "arrow.down.left",
                                tint: BrandColor.income,
                                items: viewModel.recurringIncome
                            )
                            .opacity(appeared ? 1 : 0)
                        }

                        if !viewModel.recurringExpenses.isEmpty {
                            recurringSection(
                                title: "fixed_expenses_title",
                                icon: "arrow.up.right",
                                tint: BrandColor.expense,
                                items: viewModel.recurringExpenses
                            )
                            .opacity(appeared ? 1 : 0)
                        }

                        recentTransactionsSection
                            .opacity(appeared ? 1 : 0)
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 110)
                }
                .animation(Motion.smooth, value: appeared)
                .refreshable { await viewModel.loadDashboard() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    FloatingPlusButton {
                        showAddTransaction = true
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView {
                    Task { await viewModel.loadDashboard() }
                }
            }
            .task {
                await viewModel.loadDashboard()
                withAnimation(Motion.smooth) { appeared = true }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await viewModel.loadDashboard() }
                }
            }
        }
    }

    // MARK: - Top Greeting

    private var topGreeting: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingPrefix)
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(userFirstName)
                    .font(AppFont.titleL)
                    .foregroundStyle(.primary)
            }
            Spacer()
            Text(monthName)
                .font(AppFont.label)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule().strokeBorder(Surface.separator.opacity(0.4), lineWidth: 0.5)
                )
        }
    }

    private var greetingPrefix: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return L("good_morning") }
        if hour < 17 { return L("good_afternoon") }
        return L("good_evening")
    }

    private var userFirstName: String {
        if let name = authService.currentUser?.name.split(separator: " ").first {
            return String(name)
        }
        return ""
    }

    private var monthName: String {
        let (from, _) = DateHelper.currentMonthRange()
        return DateHelper.monthName(from: from)
    }

    // MARK: - Hero Balance Card

    private var heroBalanceCard: some View {
        NavigationLink {
            BalanceDetailView(viewModel: viewModel)
        } label: {
            FeatureGlassCard(
                gradient: LinearGradient(
                    colors: [
                        BrandColor.primaryDeep,
                        BrandColor.primary,
                        BrandColor.primary.opacity(0.85),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                glowColor: BrandColor.primary
            ) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("balance")
                                .font(AppFont.label)
                                .foregroundStyle(.white.opacity(0.7))
                                .textCase(.uppercase)
                                .tracking(0.5)
                            Text(L("hero_subtitle"))
                                .font(AppFont.caption)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.18))
                                .frame(width: 32, height: 32)
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }

                    Text(CurrencyHelper.format(viewModel.summary?.balance ?? 0))
                        .font(AppFont.amountDisplay)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    HStack(spacing: 8) {
                        miniStat(label: "income", value: viewModel.summary?.income ?? 0, icon: "arrow.down.left", positive: true)
                        Rectangle().fill(Color.white.opacity(0.18)).frame(width: 1, height: 22)
                        miniStat(label: "expenses", value: viewModel.summary?.expense ?? 0, icon: "arrow.up.right", positive: false)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func miniStat(label: LocalizedStringKey, value: Double, icon: String, positive: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .textCase(.uppercase)
                    .tracking(0.4)
                Text(CurrencyHelper.format(value))
                    .font(AppFont.amountSmall)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Available to Spend

    private var availableToSpendCard: some View {
        GlassSurface(elevation: .raised) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label {
                        Text("available_to_spend")
                            .font(AppFont.titleS)
                    } icon: {
                        Image(systemName: "wallet.pass.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(BrandColor.primary)
                    }
                    Spacer()
                    StatusBadge(text: LocalizedStringKey(statusText), color: statusColor, icon: statusIcon)
                }

                Text(CurrencyHelper.format(viewModel.availableToSpend))
                    .font(AppFont.amountLarge)
                    .foregroundStyle(viewModel.availableToSpend >= 0 ? Color.primary : BrandColor.expense)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if hasBreakdown {
                    VStack(spacing: 8) {
                        Divider().padding(.vertical, 2)

                        if viewModel.totalCreditCardPending > 0 {
                            breakdownRow(icon: "creditcard.fill", label: "pending_card_charges", amount: -viewModel.totalCreditCardPending, color: BrandColor.warning)
                        }
                        if viewModel.totalPendingExpenses > 0 {
                            breakdownRow(icon: "arrow.triangle.2.circlepath", label: "upcoming_fixed_expenses", amount: -viewModel.totalPendingExpenses, color: BrandColor.expense)
                        }
                        if viewModel.totalPendingIncome > 0 {
                            breakdownRow(icon: "arrow.down.circle.fill", label: "expected_income", amount: viewModel.totalPendingIncome, color: BrandColor.income)
                        }

                        Divider().padding(.vertical, 2)

                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text("projected_end_of_month")
                                .font(AppFont.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(CurrencyHelper.format(viewModel.projectedEndOfMonth))
                                .font(AppFont.amountSmall)
                                .foregroundStyle(viewModel.projectedEndOfMonth >= 0 ? Color.primary : BrandColor.expense)
                        }
                    }
                }
            }
        }
    }

    private var hasBreakdown: Bool {
        viewModel.totalCreditCardPending > 0
            || viewModel.totalPendingExpenses > 0
            || viewModel.totalPendingIncome > 0
    }

    private func breakdownRow(icon: String, label: LocalizedStringKey, amount: Double, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.13))
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
            }
            .frame(width: 22, height: 22)

            Text(label)
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text((amount >= 0 ? "+" : "−") + CurrencyHelper.format(Swift.abs(amount)))
                .font(AppFont.amountSmall)
                .foregroundStyle(amount >= 0 ? BrandColor.income : color)
        }
    }

    private var statusColor: Color {
        let available = viewModel.availableToSpend
        if available < 0 { return BrandColor.expense }
        if available < (viewModel.summary?.income ?? 0) * 0.1 { return BrandColor.warning }
        return BrandColor.income
    }

    private var statusIcon: String {
        let available = viewModel.availableToSpend
        if available < 0 { return "exclamationmark.triangle.fill" }
        if available < (viewModel.summary?.income ?? 0) * 0.1 { return "exclamationmark.circle.fill" }
        return "checkmark.seal.fill"
    }

    private var statusText: String {
        let available = viewModel.availableToSpend
        if available < 0 { return "status_overdraft" }
        if available < (viewModel.summary?.income ?? 0) * 0.1 { return "status_tight" }
        return "status_good"
    }

    // MARK: - Income / Expense Row

    private var incomeExpenseRow: some View {
        HStack(spacing: 14) {
            statBlock(
                title: "income",
                amount: viewModel.summary?.income ?? 0,
                icon: "arrow.down.left",
                color: BrandColor.income
            )
            statBlock(
                title: "expenses",
                amount: viewModel.summary?.expense ?? 0,
                icon: "arrow.up.right",
                color: BrandColor.expense
            )
        }
    }

    private func statBlock(title: LocalizedStringKey, amount: Double, icon: String, color: Color) -> some View {
        GlassSurface(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle().fill(color.opacity(0.13))
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(color)
                    }
                    .frame(width: 28, height: 28)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                    Text(CurrencyHelper.format(amount))
                        .font(AppFont.amount)
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
    }

    // MARK: - Credit Cards Section

    private var creditCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("credit_cards")
                    .font(AppFont.titleM)
                Spacer()
                NavigationLink {
                    CreditCardListView()
                } label: {
                    HStack(spacing: 3) {
                        Text("see_all").font(AppFont.label)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    .foregroundStyle(BrandColor.primary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.creditCards) { card in
                        NavigationLink {
                            CreditCardDetailView(cardId: card.id)
                        } label: {
                            miniCard(card)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }

    private func miniCard(_ card: CreditCard) -> some View {
        let cardColor = Color(hex: card.color)
        return ZStack {
            // Base color
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: [cardColor, cardColor.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            // Glass shimmer overlay
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .blendMode(.plusLighter)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(card.name)
                        .font(AppFont.label)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "creditcard.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                if !card.lastFourDigits.isEmpty {
                    Text("• • • •  \(card.lastFourDigits)")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(1)
                }
                Text(CurrencyHelper.format(card.currentBalance ?? 0))
                    .font(AppFont.amountSmall)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(14)
        }
        .frame(width: 170, height: 110)
        .shadow(color: cardColor.opacity(0.35), radius: 12, y: 6)
    }

    // MARK: - Recurring Section (generic)

    private func recurringSection(
        title: LocalizedStringKey,
        icon: String,
        tint: Color,
        items: [DashboardRecurringItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(AppFont.titleM)
                Spacer()
                NavigationLink {
                    RecurringListView()
                } label: {
                    HStack(spacing: 3) {
                        Text("see_all").font(AppFont.label)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    .foregroundStyle(BrandColor.primary)
                }
            }

            GlassSurface(padding: 0) {
                VStack(spacing: 0) {
                    let displayItems = Array(items.prefix(4))
                    ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                        recurringRow(item: item, tint: tint)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                        if index < displayItems.count - 1 {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
            }
        }
    }

    private func recurringRow(item: DashboardRecurringItem, tint: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(tint.opacity(0.12))
                Text(item.rule.category?.icon ?? "💰")
                    .font(.system(size: 18))
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.rule.category?.localizedName ?? item.rule.note)
                    .font(AppFont.label)
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Image(systemName: item.isPending ? "clock" : "checkmark.circle.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text(item.isPending ? "status_pending" : "status_done")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(item.isPending ? BrandColor.warning : BrandColor.income)
            }

            Spacer()

            Text((item.rule.type == .income ? "+" : "−") + CurrencyHelper.format(item.rule.amount, currency: item.rule.currency))
                .font(AppFont.amountSmall)
                .foregroundStyle(item.rule.type == .income ? BrandColor.income : BrandColor.expense)
        }
        .opacity(item.isPending ? 1 : 0.7)
    }

    // MARK: - Budget Section

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("budget_status")
                    .font(AppFont.titleM)
                Spacer()
                NavigationLink {
                    BudgetListView()
                } label: {
                    HStack(spacing: 3) {
                        Text("see_all").font(AppFont.label)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    .foregroundStyle(BrandColor.primary)
                }
            }

            VStack(spacing: 8) {
                ForEach(viewModel.budgetStatuses.prefix(3)) { budget in
                    BudgetProgressView(budget: budget)
                }
            }
        }
    }

    // MARK: - Recent Transactions

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("recent_transactions")
                    .font(AppFont.titleM)
                Spacer()
                NavigationLink {
                    TransactionListView()
                } label: {
                    HStack(spacing: 3) {
                        Text("see_all").font(AppFont.label)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    .foregroundStyle(BrandColor.primary)
                }
            }

            if viewModel.recentTransactions.isEmpty && !viewModel.isLoading {
                GlassSurface(padding: 0) {
                    EmptyStateCard(
                        icon: "tray",
                        title: "no_transactions",
                        message: "add_first_transaction"
                    )
                }
            } else {
                GlassSurface(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.recentTransactions.enumerated()), id: \.element.id) { index, transaction in
                            TransactionRowView(transaction: transaction)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)

                            if index < viewModel.recentTransactions.count - 1 {
                                Divider().padding(.leading, 64)
                            }
                        }
                    }
                }
            }
        }
    }
}
