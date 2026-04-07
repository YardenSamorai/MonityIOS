import SwiftUI

struct HouseholdView: View {
    @StateObject private var viewModel = HouseholdViewModel()
    @State private var showSetup = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && !viewModel.hasHousehold {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.hasHousehold {
                    householdDashboard
                } else {
                    noHouseholdView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L("household"))
            .sheet(isPresented: $showSetup) {
                HouseholdSetupView(viewModel: viewModel)
            }
            .refreshable { await viewModel.loadAll() }
            .task { await viewModel.loadAll() }
        }
    }

    // MARK: - No Household

    private var noHouseholdView: some View {
        ScrollView {
            VStack(spacing: 24) {
                if !viewModel.invitations.isEmpty {
                    invitationsBanner
                }

                VStack(spacing: 20) {
                    Image(systemName: "house.and.flag.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(AppTheme.primaryGradient)
                        .padding(.top, 40)

                    Text("household_empty_title")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text("household_empty_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showSetup = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("create_household")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
                }
                .padding(.bottom, 40)
            }
            .padding(20)
        }
    }

    // MARK: - Invitations Banner

    private var invitationsBanner: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.invitations) { invitation in
                HouseholdInvitationCard(
                    invitation: invitation,
                    onAccept: { Task { await viewModel.acceptInvitation(invitation.id) } },
                    onDecline: { Task { await viewModel.declineInvitation(invitation.id) } }
                )
            }
        }
    }

    // MARK: - Household Dashboard

    private var householdDashboard: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                membersHeader

                sharedBalanceCard

                sharedIncomeExpenseRow

                if !viewModel.creditCards.isEmpty {
                    sharedCreditCardsSection
                }

                sharedTransactionsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Members Header

    private var membersHeader: some View {
        SolidCard {
            HStack(spacing: 16) {
                ForEach(viewModel.household?.activeMembers ?? []) { member in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(member.isOwner ? AppTheme.primaryGradient : AppTheme.incomeGradient)
                                .frame(width: 40, height: 40)
                            Text(String(member.displayName.prefix(1)).uppercased())
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.displayName)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(member.isOwner ? L("household_owner") : L("household_member"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if member.id != viewModel.household?.activeMembers.last?.id {
                        Spacer()
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.pink.opacity(0.6))
                        Spacer()
                    }
                }

                if (viewModel.household?.activeMembers.count ?? 0) < 2 {
                    Spacer()
                    NavigationLink {
                        HouseholdInviteView(viewModel: viewModel)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                            Text("invite_partner")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.accent.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Shared Balance

    private var sharedBalanceCard: some View {
        VStack(spacing: 8) {
            Text("shared_balance")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))

            Text(CurrencyHelper.format(viewModel.summary?.balance ?? 0))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            let (from, _) = DateHelper.currentMonthRange()
            Text(DateHelper.monthName(from: from))
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))

            if let byMember = viewModel.summary?.byMember, byMember.count > 1 {
                Divider()
                    .background(.white.opacity(0.3))
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                HStack(spacing: 20) {
                    ForEach(byMember, id: \.userId) { member in
                        VStack(spacing: 4) {
                            Text(member.name.split(separator: " ").first.map(String.init) ?? member.name)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.7))
                            Text(CurrencyHelper.format(member.income - member.expense))
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "6C63FF"), Color(hex: "E17055")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(hex: "6C63FF").opacity(0.3), radius: 20, y: 10)
        )
    }

    // MARK: - Shared Income/Expense

    private var sharedIncomeExpenseRow: some View {
        HStack(spacing: 14) {
            sharedSummaryCard(
                title: "expenses",
                amount: viewModel.summary?.expense ?? 0,
                icon: "arrow.up.right",
                color: AppTheme.expense,
                gradient: AppTheme.expenseGradient
            )

            sharedSummaryCard(
                title: "income",
                amount: viewModel.summary?.income ?? 0,
                icon: "arrow.down.left",
                color: AppTheme.income,
                gradient: AppTheme.incomeGradient
            )
        }
    }

    private func sharedSummaryCard(
        title: LocalizedStringKey, amount: Double,
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

                Text(CurrencyHelper.format(amount))
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let byMember = viewModel.summary?.byMember, byMember.count > 1 {
                    VStack(spacing: 3) {
                        ForEach(byMember, id: \.userId) { member in
                            HStack(spacing: 4) {
                                Circle().fill(color.opacity(0.5)).frame(width: 5, height: 5)
                                Text(member.name.split(separator: " ").first.map(String.init) ?? member.name)
                                    .font(.system(size: 9).weight(.medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                let memberAmount = title == "expenses" as LocalizedStringKey ? member.expense : member.income
                                Text(CurrencyHelper.format(memberAmount))
                                    .font(.system(size: 9).weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Shared Credit Cards

    private var sharedCreditCardsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("credit_cards")
                .font(.title3.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.creditCards) { card in
                        miniCreditCard(card)
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
        }
        .frame(width: 160, height: 90)
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

    // MARK: - Shared Transactions

    private var sharedTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("recent_transactions")
                .font(.title3.weight(.semibold))

            if viewModel.recentTransactions.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    icon: "tray",
                    title: "no_transactions",
                    message: "household_no_transactions_message"
                )
            } else {
                SolidCard {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.recentTransactions.enumerated()), id: \.element.id) { index, transaction in
                            HouseholdTransactionRow(transaction: transaction)
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

// MARK: - Household Transaction Row (with partner attribution)

struct HouseholdTransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 14) {
            Text(transaction.category?.icon ?? "💰")
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(categoryColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.category?.localizedName ?? L("uncategorized"))
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 4) {
                    if let userName = transaction.user?.name {
                        Text(userName.split(separator: " ").first.map(String.init) ?? userName)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    if !transaction.note.isEmpty {
                        Text(transaction.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(formattedAmount)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(transaction.type == .income ? AppTheme.income : .primary)

                Text(DateHelper.display(transaction.date))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var formattedAmount: String {
        let prefix = transaction.type == .income ? "+" : "-"
        return prefix + CurrencyHelper.format(transaction.amount, currency: transaction.currency)
    }

    private var categoryColor: Color {
        guard let hex = transaction.category?.color else { return AppTheme.accent }
        return Color(hex: hex)
    }
}

// MARK: - Invitation Card

struct HouseholdInvitationCard: View {
    let invitation: HouseholdInvitation
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        SolidCard {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primaryGradient)
                            .frame(width: 44, height: 44)
                        Image(systemName: "house.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("pending_invitation")
                            .font(.subheadline.weight(.semibold))
                        Text("\(invitation.invitedByName) \(L("invited_you"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onDecline()
                    } label: {
                        Text("decline")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onAccept()
                    } label: {
                        Text("accept")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.primaryGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .padding(16)
        }
    }
}
