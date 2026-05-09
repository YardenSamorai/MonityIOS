import SwiftUI
import Charts

struct BalanceDetailView: View {
    @ObservedObject var viewModel: DashboardViewModel

    private var currency: String {
        AuthService.shared.currentUser?.preferredCurrency ?? "ILS"
    }

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    balanceHeader
                    balanceChart
                    summaryRow
                    breakdownSection
                    transactionTimeline
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(L("balance_details"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadMonthTransactions() }
    }

    private var balanceHeader: some View {
        VStack(spacing: 6) {
            Text("balance")
                .font(AppFont.label)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(CurrencyHelper.format(viewModel.summary?.balance ?? 0, currency: currency))
                .font(AppFont.amountDisplay)
            let (from, _) = DateHelper.currentMonthRange()
            Text(DateHelper.monthName(from: from))
                .font(AppFont.bodyS)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var balanceChart: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(BrandColor.primary.opacity(0.13))
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(BrandColor.primary)
                    }
                    .frame(width: 30, height: 30)
                    Text(L("balance_over_time"))
                        .font(AppFont.titleS)
                }

                if viewModel.balanceChartData.count >= 2 {
                    Chart(viewModel.balanceChartData) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Balance", point.balance)
                        )
                        .foregroundStyle(BrandColor.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Balance", point.balance)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [BrandColor.primary.opacity(0.25), BrandColor.primary.opacity(0.0)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                            AxisValueLabel(format: .dateTime.day())
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                                .foregroundStyle(Surface.separator)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(shortCurrency(v))
                                        .font(.caption2)
                                }
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                                .foregroundStyle(Surface.separator)
                        }
                    }
                    .frame(height: 200)
                } else {
                    Text(L("no_transactions_this_month"))
                        .font(AppFont.body)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                }
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            summaryCard(title: "income", amount: viewModel.summary?.income ?? 0, icon: "arrow.down.left", color: BrandColor.income)
            summaryCard(title: "expenses", amount: viewModel.summary?.expense ?? 0, icon: "arrow.up.right", color: BrandColor.expense)
        }
    }

    private func summaryCard(title: LocalizedStringKey, amount: Double, icon: String, color: Color) -> some View {
        GlassSurface(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                    Text(CurrencyHelper.format(amount, currency: currency))
                        .font(AppFont.amount)
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
    }

    private var breakdownSection: some View {
        GlassSurface(padding: 0) {
            VStack(spacing: 0) {
                breakdownRow(label: L("fixed_short"), income: viewModel.fixedIncomeDone, expense: viewModel.fixedExpensesDone)
                Divider()
                breakdownRow(label: L("variable_short"), income: viewModel.variableIncome, expense: viewModel.variableExpenses)
            }
        }
    }

    private func breakdownRow(label: String, income: Double, expense: Double) -> some View {
        HStack {
            Text(label)
                .font(AppFont.label)
                .frame(width: 90, alignment: .leading)
            Spacer()
            Text("+" + CurrencyHelper.format(income, currency: currency))
                .font(AppFont.amountSmall)
                .foregroundStyle(BrandColor.income)
            Spacer().frame(width: 16)
            Text("−" + CurrencyHelper.format(expense, currency: currency))
                .font(AppFont.amountSmall)
                .foregroundStyle(BrandColor.expense)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var transactionTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("transactions"))
                .font(AppFont.titleM)
                .padding(.leading, 4)

            if viewModel.transactionGroups.isEmpty {
                GlassSurface {
                    EmptyStateCard(
                        icon: "tray",
                        title: "no_transactions",
                        message: "no_transactions_this_month"
                    )
                }
            } else {
                ForEach(viewModel.transactionGroups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(formatGroupDate(group.date))
                            .font(AppFont.label)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.leading, 4)
                        GlassSurface(padding: 0) {
                            VStack(spacing: 0) {
                                ForEach(Array(group.transactions.enumerated()), id: \.element.id) { index, item in
                                    if index > 0 { Divider().padding(.leading, 60) }
                                    timelineRow(item)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func timelineRow(_ item: TransactionWithBalance) -> some View {
        let t = item.transaction
        let isIncome = t.type == .income
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(categoryColor(t).opacity(0.13))
                Text(t.category?.icon ?? "💰").font(.system(size: 18))
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(t.category?.localizedName ?? L("uncategorized"))
                    .font(AppFont.label)
                    .lineLimit(1)
                if !t.note.isEmpty {
                    Text(t.note).font(AppFont.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text((isIncome ? "+" : "−") + CurrencyHelper.format(t.amount, currency: t.currency))
                    .font(AppFont.amountSmall)
                    .foregroundStyle(isIncome ? BrandColor.income : BrandColor.expense)
                Text(CurrencyHelper.format(item.balanceAfter, currency: currency))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func categoryColor(_ t: Transaction) -> Color {
        guard let hex = t.category?.color else { return BrandColor.primary }
        return Color(hex: hex)
    }

    private func shortCurrency(_ value: Double) -> String {
        if abs(value) >= 1000 { return String(format: "%.0fK", value / 1000) }
        return String(format: "%.0f", value)
    }

    private func formatGroupDate(_ date: Date) -> String {
        let lang = UserDefaults.standard.string(forKey: "app_language") ?? "he"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: lang)
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: date)
    }
}
