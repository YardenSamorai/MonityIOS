import SwiftUI

struct CreditCardDetailView: View {
    let cardId: String
    @StateObject private var viewModel = CreditCardViewModel()
    @State private var showBillAlert = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if let card = viewModel.selectedCard {
                    CreditCardVisual(card: card)

                    HStack(spacing: 12) {
                        infoCard(
                            title: "next_billing",
                            value: nextBillingDateString(card.billingDay),
                            icon: "calendar",
                            gradient: AppTheme.primaryGradient
                        )
                        infoCard(
                            title: "current_balance",
                            value: CurrencyHelper.format(card.currentBalance ?? 0),
                            icon: "sheqelsign.circle",
                            gradient: AppTheme.expenseGradient
                        )
                    }

                    if let lastBilled = card.lastBilledAt {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.income)
                            Text("last_billed")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text(DateHelper.display(lastBilled))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(AppTheme.income.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if (card.currentBalance ?? 0) > 0 {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showBillAlert = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.body.weight(.medium))
                                Text("bill_now")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.expenseGradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    Divider().padding(.vertical, 4)

                    monthNavigator

                    if let summary = viewModel.historySummary {
                        monthlySummaryCard(summary)
                    }

                    historyTransactionsList

                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                }
            }
            .padding(20)
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(viewModel.selectedCard?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .alert("bill_confirm_title", isPresented: $showBillAlert) {
            Button("cancel", role: .cancel) {}
            Button("bill_now", role: .destructive) {
                Task {
                    await viewModel.billCard(cardId)
                    await viewModel.loadCardDetail(cardId)
                    await viewModel.loadCardHistory(cardId)
                }
            }
        } message: {
            if let balance = viewModel.selectedCard?.currentBalance {
                Text("bill_confirm_message \(CurrencyHelper.format(balance))")
            }
        }
        .refreshable {
            await viewModel.loadCardDetail(cardId)
            await viewModel.loadCardHistory(cardId)
        }
        .task {
            await viewModel.loadCardDetail(cardId)
            await viewModel.loadCardHistory(cardId)
        }
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button {
                Task { await viewModel.navigateMonth(cardId, direction: -1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundColor(viewModel.canGoBack ? AppTheme.accent : Color.gray.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .background(viewModel.canGoBack ? AppTheme.accent.opacity(0.1) : Color.clear)
                    .clipShape(Circle())
            }
            .disabled(!viewModel.canGoBack)

            Spacer()

            VStack(spacing: 2) {
                Text("billing_history")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(viewModel.selectedMonthDisplayName.capitalized)
                    .font(.headline.weight(.bold))
            }

            Spacer()

            Button {
                Task { await viewModel.navigateMonth(cardId, direction: 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundColor(viewModel.canGoForward ? AppTheme.accent : Color.gray.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .background(viewModel.canGoForward ? AppTheme.accent.opacity(0.1) : Color.clear)
                    .clipShape(Circle())
            }
            .disabled(!viewModel.canGoForward)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Monthly Summary

    private func monthlySummaryCard(_ summary: CreditCardHistorySummary) -> some View {
        SolidCard {
            VStack(spacing: 12) {
                HStack {
                    summaryRow(title: "total_expenses", amount: summary.totalExpenses, color: AppTheme.expense)
                    Spacer()
                    summaryRow(title: "total_credits", amount: summary.totalCredits, color: AppTheme.income)
                }

                Divider()

                HStack {
                    Text("net_charge")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(CurrencyHelper.format(summary.netCharge))
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(summary.netCharge > 0 ? AppTheme.expense : AppTheme.income)
                }
            }
            .padding(16)
        }
    }

    private func summaryRow(title: LocalizedStringKey, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(CurrencyHelper.format(amount))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
    }

    // MARK: - History Transactions List

    private var historyTransactionsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            if viewModel.historyTransactions.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    icon: "creditcard.trianglebadge.exclamationmark",
                    title: "no_charges_this_month",
                    message: "card_transactions_empty_message"
                )
            } else if !viewModel.historyTransactions.isEmpty {
                SolidCard {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.historyTransactions.enumerated()), id: \.element.id) { index, transaction in
                            TransactionRowView(transaction: transaction)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)

                            if index < viewModel.historyTransactions.count - 1 {
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Info Card

    private func infoCard(title: LocalizedStringKey, value: String, icon: String, gradient: LinearGradient) -> some View {
        SolidCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    private func nextBillingDateString(_ billingDay: Int) -> String {
        let cal = Calendar.current
        let now = Date()
        let currentDay = cal.component(.day, from: now)

        var components = cal.dateComponents([.year, .month], from: now)
        if currentDay >= billingDay {
            components.month = (components.month ?? 1) + 1
        }
        components.day = billingDay

        if let date = cal.date(from: components) {
            return DateHelper.displayFormatter.string(from: date)
        }
        return "\(billingDay)"
    }
}
