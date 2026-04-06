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

                    SolidCard {
                        HStack(spacing: 12) {
                            Image(systemName: "gearshape.2.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.accent)
                            Text("auto_billing_note")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
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

                    VStack(alignment: .leading, spacing: 14) {
                        Text("card_transactions")
                            .font(.title3.weight(.semibold))

                        if viewModel.cardTransactions.isEmpty {
                            EmptyStateView(
                                icon: "creditcard.trianglebadge.exclamationmark",
                                title: "no_card_transactions",
                                message: "card_transactions_empty_message"
                            )
                        } else {
                            SolidCard {
                                VStack(spacing: 0) {
                                    ForEach(Array(viewModel.cardTransactions.enumerated()), id: \.element.id) { index, transaction in
                                        TransactionRowView(transaction: transaction)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)

                                        if index < viewModel.cardTransactions.count - 1 {
                                            Divider().padding(.leading, 68)
                                        }
                                    }
                                }
                            }
                        }
                    }
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
                Task { await viewModel.billCard(cardId) }
            }
        } message: {
            if let balance = viewModel.selectedCard?.currentBalance {
                Text("bill_confirm_message \(CurrencyHelper.format(balance))")
            }
        }
        .refreshable { await viewModel.loadCardDetail(cardId) }
        .task { await viewModel.loadCardDetail(cardId) }
    }

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
