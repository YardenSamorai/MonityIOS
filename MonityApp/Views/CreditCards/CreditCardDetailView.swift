import SwiftUI

struct CreditCardDetailView: View {
    let cardId: String
    @StateObject private var viewModel = CreditCardViewModel()
    @State private var showBillAlert = false
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    if let card = viewModel.selectedCard {
                        CreditCardVisual(
                            card: card,
                            displayBalance: isCurrentMonth ? nil : viewModel.historySummary?.netCharge
                        )

                        statRow(card: card)

                        if isCurrentMonth, let lastBilled = card.lastBilledAt {
                            lastBilledStrip(date: lastBilled)
                        }

                        if isCurrentMonth && (card.currentBalance ?? 0) > 0 {
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                showBillAlert = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.seal.fill")
                                    Text("bill_now").font(.subheadline.weight(.bold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundStyle(.white)
                                .background(LinearGradient(
                                    colors: [BrandColor.expense, BrandColor.expense.opacity(0.8)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                                .shadow(color: BrandColor.expense.opacity(0.3), radius: 10, y: 4)
                            }
                        }

                        monthNavigator

                        if let summary = viewModel.historySummary {
                            monthlySummaryCard(summary)
                        }

                        historyTransactionsList
                    } else if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
            .refreshable {
                await viewModel.loadCardDetail(cardId)
                await viewModel.loadCardHistory(cardId)
            }
        }
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
                let formatted = CurrencyHelper.format(balance)
                Text(String(format: NSLocalizedString("bill_confirm_message %@", comment: ""), formatted))
            }
        }
        .task {
            await viewModel.loadCardDetail(cardId)
            await viewModel.loadCardHistory(cardId)
        }
    }

    private var isCurrentMonth: Bool {
        let now = Date()
        let cal = Calendar.current
        let y = cal.component(.year, from: now)
        let m = cal.component(.month, from: now)
        return viewModel.selectedMonth == "\(y)-\(String(format: "%02d", m))"
    }

    // MARK: - Stat Row

    private func statRow(card: CreditCard) -> some View {
        HStack(spacing: 12) {
            statBlock(
                icon: "calendar.badge.clock",
                title: isCurrentMonth ? "next_billing" : "billing_history",
                value: isCurrentMonth ? nextBillingDateString(card.billingDay) : viewModel.selectedMonthDisplayName,
                color: BrandColor.primary
            )
            statBlock(
                icon: "creditcard.fill",
                title: "current_balance",
                value: CurrencyHelper.format(isCurrentMonth ? (card.currentBalance ?? 0) : (viewModel.historySummary?.netCharge ?? 0)),
                color: BrandColor.expense
            )
        }
    }

    private func statBlock(icon: String, title: LocalizedStringKey, value: String, color: Color) -> some View {
        GlassSurface(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Circle().fill(color.opacity(0.13))
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(color)
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                    Text(value)
                        .font(AppFont.amountSmall)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }

    private func lastBilledStrip(date: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.subheadline)
                .foregroundStyle(BrandColor.income)
            Text("last_billed")
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
            Text(DateHelper.display(date))
                .font(AppFont.label)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(12)
        .background(BrandColor.income.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(BrandColor.income.opacity(0.18), lineWidth: 0.5)
        )
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        // RTL aware
        let isRTL = layoutDirection == .rightToLeft
        let backIcon = isRTL ? "chevron.right" : "chevron.left"
        let forwardIcon = isRTL ? "chevron.left" : "chevron.right"

        return GlassSurface(padding: 8) {
            HStack {
                navButton(icon: backIcon, enabled: viewModel.canGoBack) {
                    Task { await viewModel.navigateMonth(cardId, direction: -1) }
                }
                Spacer()
                VStack(spacing: 1) {
                    Text("billing_history")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                    Text(viewModel.selectedMonthDisplayName)
                        .font(AppFont.titleS)
                }
                Spacer()
                navButton(icon: forwardIcon, enabled: viewModel.canGoForward) {
                    Task { await viewModel.navigateMonth(cardId, direction: 1) }
                }
            }
        }
    }

    private func navButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(enabled ? BrandColor.primary : Color.secondary.opacity(0.4))
                .frame(width: 36, height: 36)
                .background(enabled ? BrandColor.primary.opacity(0.12) : Color.clear)
                .clipShape(Circle())
        }
        .disabled(!enabled)
    }

    // MARK: - Monthly Summary

    private func monthlySummaryCard(_ summary: CreditCardHistorySummary) -> some View {
        GlassSurface {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    summaryItem(title: "total_expenses", amount: summary.totalExpenses, color: BrandColor.expense)
                    Divider().frame(height: 36)
                    summaryItem(title: "total_credits", amount: summary.totalCredits, color: BrandColor.income)
                }

                Divider()

                HStack {
                    Text("net_charge").font(AppFont.titleS)
                    Spacer()
                    Text(CurrencyHelper.format(summary.netCharge))
                        .font(AppFont.amount)
                        .foregroundStyle(summary.netCharge > 0 ? BrandColor.expense : BrandColor.income)
                }
            }
        }
    }

    private func summaryItem(title: LocalizedStringKey, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(CurrencyHelper.format(amount))
                .font(AppFont.amountSmall)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - History Transactions

    private var historyTransactionsList: some View {
        Group {
            if viewModel.historyTransactions.isEmpty && !viewModel.isLoading {
                GlassSurface {
                    EmptyStateCard(
                        icon: "creditcard.trianglebadge.exclamationmark",
                        title: "no_charges_this_month",
                        message: "card_transactions_empty_message"
                    )
                }
            } else if !viewModel.historyTransactions.isEmpty {
                GlassSurface(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.historyTransactions.enumerated()), id: \.element.id) { index, transaction in
                            TransactionRowView(transaction: transaction)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                            if index < viewModel.historyTransactions.count - 1 {
                                Divider().padding(.leading, 64)
                            }
                        }
                    }
                }
            }
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
