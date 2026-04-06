import SwiftUI
import Charts

struct BalanceDetailView: View {
    @ObservedObject var viewModel: DashboardViewModel

    private var currency: String {
        AuthService.shared.currentUser?.preferredCurrency ?? "ILS"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                balanceHeader
                balanceChart
                summaryRow
                breakdownSection
                transactionTimeline
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L("balance_details"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadMonthTransactions()
        }
    }

    // MARK: - Balance Header

    private var balanceHeader: some View {
        VStack(spacing: 6) {
            Text(CurrencyHelper.format(viewModel.summary?.balance ?? 0, currency: currency))
                .font(.system(size: 36, weight: .bold, design: .rounded))

            let (from, _) = DateHelper.currentMonthRange()
            Text(DateHelper.monthName(from: from))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Balance Chart

    private var balanceChart: some View {
        SolidCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(L("balance_over_time"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                if viewModel.balanceChartData.count >= 2 {
                    Chart(viewModel.balanceChartData) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Balance", point.balance)
                        )
                        .foregroundStyle(AppTheme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Balance", point.balance)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.accent.opacity(0.2), AppTheme.accent.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 7)) { value in
                            AxisValueLabel(format: .dateTime.day())
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                                .foregroundStyle(Color(.systemGray4))
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
                                .foregroundStyle(Color(.systemGray4))
                        }
                    }
                    .frame(height: 200)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                } else {
                    HStack {
                        Spacer()
                        Text(L("no_transactions_this_month"))
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .frame(height: 120)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    // MARK: - Income / Expense Summary

    private var summaryRow: some View {
        HStack(spacing: 12) {
            summaryCard(
                title: L("income"),
                amount: viewModel.summary?.income ?? 0,
                icon: "arrow.down.left",
                color: AppTheme.income,
                gradient: AppTheme.incomeGradient
            )
            summaryCard(
                title: L("expenses"),
                amount: viewModel.summary?.expense ?? 0,
                icon: "arrow.up.right",
                color: AppTheme.expense,
                gradient: AppTheme.expenseGradient
            )
        }
    }

    private func summaryCard(title: String, amount: Double, icon: String, color: Color, gradient: LinearGradient) -> some View {
        SolidCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(gradient)
                        .clipShape(Circle())
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Text(CurrencyHelper.format(amount, currency: currency))
                    .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    // MARK: - Breakdown

    private var breakdownSection: some View {
        SolidCard {
            VStack(spacing: 0) {
                breakdownRow(
                    label: L("fixed_short"),
                    income: viewModel.fixedIncomeDone,
                    expense: viewModel.fixedExpensesDone
                )
                Divider().padding(.horizontal, 16)
                breakdownRow(
                    label: L("variable_short"),
                    income: viewModel.variableIncome,
                    expense: viewModel.variableExpenses
                )
            }
        }
    }

    private func breakdownRow(label: String, income: Double, expense: Double) -> some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.medium))
                .frame(width: 70, alignment: .leading)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("+" + CurrencyHelper.format(income, currency: currency))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppTheme.income)
            }

            Spacer().frame(width: 20)

            VStack(alignment: .trailing, spacing: 2) {
                Text("-" + CurrencyHelper.format(expense, currency: currency))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppTheme.expense)
            }
        }
        .padding(16)
    }

    // MARK: - Transaction Timeline

    private var transactionTimeline: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("transactions"))
                .font(.headline)
                .padding(.leading, 4)

            if viewModel.transactionGroups.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text(L("no_transactions_this_month"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 40)
            } else {
                ForEach(viewModel.transactionGroups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(formatGroupDate(group.date))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)

                        SolidCard {
                            VStack(spacing: 0) {
                                ForEach(Array(group.transactions.enumerated()), id: \.element.id) { index, item in
                                    if index > 0 {
                                        Divider().padding(.leading, 60)
                                    }
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
            Text(t.category?.icon ?? "💰")
                .font(.body)
                .frame(width: 38, height: 38)
                .background(categoryColor(t).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(t.category?.localizedName ?? L("uncategorized"))
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if !t.note.isEmpty {
                    Text(t.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text((isIncome ? "+" : "-") + CurrencyHelper.format(t.amount, currency: t.currency))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(isIncome ? AppTheme.income : AppTheme.expense)

                Text(L("balance_after") + " " + CurrencyHelper.format(item.balanceAfter, currency: currency))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func categoryColor(_ t: Transaction) -> Color {
        guard let hex = t.category?.color else { return AppTheme.accent }
        return Color(hex: hex)
    }

    private func shortCurrency(_ value: Double) -> String {
        if abs(value) >= 1000 {
            return String(format: "%.0fK", value / 1000)
        }
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
