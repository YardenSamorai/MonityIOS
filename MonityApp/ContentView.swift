import SwiftUI

struct ContentView: View {
    @EnvironmentObject var invitationCenter: HouseholdInvitationCenter
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if !invitationCenter.invitations.isEmpty {
                    householdInvitesStrip
                }

                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(.keyboard)
            }

            FloatingGlassTabBar(
                selection: $selectedTab,
                pendingHouseholdInvites: invitationCenter.invitations.count
            )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .background(CanvasBackground())
        .ignoresSafeArea(.keyboard)
        .task {
            await invitationCenter.refresh()
        }
    }

    private var householdInvitesStrip: some View {
        VStack(spacing: 6) {
            Text("household_invite_banner_title")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, 10)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(invitationCenter.invitations) { invitation in
                        HouseholdInvitationCard(
                            invitation: invitation,
                            onAccept: {
                                Task { await invitationCenter.acceptInvitation(invitation.id) }
                            },
                            onDecline: {
                                Task { await invitationCenter.declineInvitation(invitation.id) }
                            }
                        )
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, 12)
            }
            .frame(maxHeight: 240)
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .dashboard:    DashboardView()
        case .transactions: TransactionListView()
        case .charts:       ChartsView()
        case .cards:        CreditCardListView()
        case .more:         MoreMenuView(selection: $selectedTab)
        }
    }
}

// MARK: - Tabs

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard, transactions, charts, cards, more

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .dashboard:    return "tab_overview"
        case .transactions: return "tab_activity"
        case .charts:       return "tab_insights"
        case .cards:        return "tab_cards"
        case .more:         return "tab_more"
        }
    }

    var icon: String {
        switch self {
        case .dashboard:    return "rectangle.grid.2x2"
        case .transactions: return "list.bullet"
        case .charts:       return "chart.bar.xaxis"
        case .cards:        return "creditcard"
        case .more:         return "ellipsis.circle"
        }
    }

    var iconActive: String {
        switch self {
        case .dashboard:    return "rectangle.grid.2x2.fill"
        case .transactions: return "list.bullet.rectangle.fill"
        case .charts:       return "chart.bar.xaxis"
        case .cards:        return "creditcard.fill"
        case .more:         return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Floating Glass Tab Bar

struct FloatingGlassTabBar: View {
    @Binding var selection: AppTab
    var pendingHouseholdInvites: Int = 0
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(6)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Surface.card.opacity(0.55))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Surface.separator.opacity(0.4), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 16, y: 6)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isActive = selection == tab
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selection = tab
            }
        } label: {
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(BrandColor.primary)
                        .matchedGeometryEffect(id: "indicator", in: indicator)
                        .shadow(color: BrandColor.primary.opacity(0.4), radius: 10, y: 4)
                }

                VStack(spacing: 3) {
                    Image(systemName: isActive ? tab.iconActive : tab.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .overlay(alignment: .topTrailing) {
                            if tab == .more && pendingHouseholdInvites > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 7, height: 7)
                                    .offset(x: 5, y: -4)
                            }
                        }
                    if isActive {
                        Text(LocalizedStringKey(tab.titleKey))
                            .font(.system(size: 10, weight: .bold))
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(isActive ? Color.white : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .contentShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - More Menu (Settings, Recurring, Household)

struct MoreMenuView: View {
    @Binding var selection: AppTab

    @State private var navigationTarget: MoreItem?

    enum MoreItem: String, Identifiable, CaseIterable {
        case household, recurring, budgets, settings

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .household: return "person.2.fill"
            case .recurring: return "arrow.triangle.2.circlepath"
            case .budgets:   return "chart.pie.fill"
            case .settings:  return "gearshape.fill"
            }
        }

        var titleKey: String {
            switch self {
            case .household: return "household"
            case .recurring: return "recurring_transactions"
            case .budgets:   return "budgets"
            case .settings:  return "settings"
            }
        }

        var subtitleKey: String {
            switch self {
            case .household: return "more_household_subtitle"
            case .recurring: return "more_recurring_subtitle"
            case .budgets:   return "more_budgets_subtitle"
            case .settings:  return "more_settings_subtitle"
            }
        }

        var color: Color {
            switch self {
            case .household: return BrandColor.info
            case .recurring: return BrandColor.income
            case .budgets:   return BrandColor.accent
            case .settings:  return BrandColor.primary
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()
                ScrollView {
                    VStack(spacing: Spacing.md) {
                        ForEach(MoreItem.allCases) { item in
                            NavigationLink(value: item) {
                                row(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, 110)
                }
            }
            .navigationTitle(LocalizedStringKey("tab_more"))
            .navigationDestination(for: MoreItem.self) { item in
                switch item {
                case .household: HouseholdView()
                case .recurring: RecurringListView()
                case .budgets:   BudgetListView()
                case .settings:  SettingsView()
                }
            }
        }
    }

    private func row(_ item: MoreItem) -> some View {
        GlassSurface(cornerRadius: Radius.lg, padding: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(item.color.opacity(0.15))
                    Image(systemName: item.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(item.color)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(item.titleKey))
                        .font(AppFont.titleS)
                        .foregroundStyle(.primary)
                    Text(LocalizedStringKey(item.subtitleKey))
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
    }
}
