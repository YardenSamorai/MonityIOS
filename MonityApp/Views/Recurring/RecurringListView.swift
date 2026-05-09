import SwiftUI

struct RecurringListView: View {
    @StateObject private var viewModel = RecurringViewModel()
    @State private var showAddRecurring = false
    @State private var editingRule: RecurringRule?
    @State private var ruleToDelete: RecurringRule?

    var body: some View {
        ZStack {
            CanvasBackground()

            if viewModel.rules.isEmpty && !viewModel.isLoading {
                EmptyStateCard(
                    icon: "arrow.triangle.2.circlepath",
                    title: "no_recurring",
                    message: "add_first_recurring",
                    actionTitle: "add_recurring",
                    action: { showAddRecurring = true }
                )
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(viewModel.rules) { rule in
                            Button {
                                editingRule = rule
                            } label: {
                                RecurringRuleCard(rule: rule) {
                                    Task { await viewModel.toggleActive(rule) }
                                }
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    ruleToDelete = rule
                                } label: {
                                    Label("delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    editingRule = rule
                                } label: {
                                    Label("edit", systemImage: "pencil")
                                }
                                .tint(BrandColor.primary)

                                Button {
                                    Task {
                                        let ok = await viewModel.runRuleNow(rule.id)
                                        if ok { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                                    }
                                } label: {
                                    Label("run_now", systemImage: "play.fill")
                                }
                                .tint(BrandColor.income)
                            }
                            .contextMenu {
                                Button {
                                    Task {
                                        let ok = await viewModel.runRuleNow(rule.id)
                                        if ok { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                                    }
                                } label: { Label("run_now", systemImage: "play.fill") }
                                Button { editingRule = rule } label: { Label("edit", systemImage: "pencil") }
                                Button(role: .destructive) { ruleToDelete = rule } label: { Label("delete", systemImage: "trash") }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
                }
                .refreshable { await viewModel.loadRules() }
            }
        }
        .navigationTitle("recurring_transactions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                FloatingPlusButton { showAddRecurring = true }
            }
        }
        .confirmationDialog(L("delete_recurring_confirm"), isPresented: .init(
            get: { ruleToDelete != nil },
            set: { if !$0 { ruleToDelete = nil } }
        ), titleVisibility: .visible) {
            Button(L("delete"), role: .destructive) {
                guard let rule = ruleToDelete else { return }
                Task {
                    await viewModel.deleteRule(rule.id)
                    if viewModel.errorMessage != nil {
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                    } else {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    ruleToDelete = nil
                }
            }
        } message: {
            Text("delete_recurring_message")
        }
        .alert(L("error"), isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L("ok")) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showAddRecurring) {
            AddRecurringView { Task { await viewModel.loadRules() } }
        }
        .sheet(item: $editingRule) { rule in
            AddRecurringView(editingRule: rule) { Task { await viewModel.loadRules() } }
        }
        .task { await viewModel.loadRules() }
    }
}

struct RecurringRuleCard: View {
    let rule: RecurringRule
    var onToggle: () -> Void

    var body: some View {
        GlassSurface(padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(categoryColor.opacity(0.13))
                        Text(rule.category?.icon ?? "💰")
                            .font(.system(size: 20))
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(rule.category?.localizedName ?? L("uncategorized"))
                            .font(AppFont.titleS)

                        if !rule.note.isEmpty {
                            Text(rule.note)
                                .font(AppFont.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formattedAmount)
                            .font(AppFont.amount)
                            .foregroundStyle(rule.type == .income ? BrandColor.income : BrandColor.expense)
                        Text(LocalizedStringKey(rule.frequency.rawValue))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(frequencyColor)
                            .clipShape(Capsule())
                    }
                }
                .padding(16)

                Divider()

                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                        Text(nextExecutionText)
                            .font(AppFont.caption)
                    }
                    .foregroundStyle(BrandColor.primary)

                    Spacer()

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onToggle()
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(rule.isActive ? BrandColor.income : Color.gray)
                                .frame(width: 7, height: 7)
                            Text(rule.isActive ? "active" : "paused")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(rule.isActive ? BrandColor.income : .gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(rule.isActive ? BrandColor.income.opacity(0.12) : Color.gray.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .opacity(rule.isActive ? 1 : 0.6)
    }

    private var formattedAmount: String {
        let prefix = rule.type == .income ? "+" : "−"
        return prefix + CurrencyHelper.format(rule.amount, currency: rule.currency)
    }

    private var categoryColor: Color {
        guard let hex = rule.category?.color else { return BrandColor.primary }
        return Color(hex: hex)
    }

    private var nextExecutionText: String {
        guard let startDate = DateHelper.fromAPIString(rule.startDate) else {
            return DateHelper.display(rule.startDate)
        }
        let cal = Calendar.current
        let now = Date()
        var next: Date?

        switch rule.frequency {
        case .daily:
            next = cal.startOfDay(for: now) <= cal.startOfDay(for: startDate) ? startDate : cal.date(byAdding: .day, value: 1, to: now)
        case .weekly:
            let targetWeekday = cal.component(.weekday, from: startDate)
            var comps = DateComponents()
            comps.weekday = targetWeekday
            next = cal.nextDate(after: now, matching: comps, matchingPolicy: .nextTime)
        case .monthly:
            let targetDay = cal.component(.day, from: startDate)
            let currentDay = cal.component(.day, from: now)
            var comps = cal.dateComponents([.year, .month], from: now)
            let lastDay = cal.range(of: .day, in: .month, for: now)?.count ?? 28
            comps.day = min(targetDay, lastDay)
            if currentDay >= targetDay {
                comps.month = (comps.month ?? 1) + 1
            }
            next = cal.date(from: comps)
        case .yearly:
            let targetMonth = cal.component(.month, from: startDate)
            let targetDay = cal.component(.day, from: startDate)
            var comps = DateComponents()
            comps.year = cal.component(.year, from: now)
            comps.month = targetMonth
            comps.day = targetDay
            if let d = cal.date(from: comps), d <= now {
                comps.year = (comps.year ?? 2026) + 1
            }
            next = cal.date(from: comps)
        }

        if let next {
            return DateHelper.displayFormatter.string(from: next)
        }
        return DateHelper.display(rule.startDate)
    }

    private var frequencyColor: Color {
        switch rule.frequency {
        case .daily:   return BrandColor.warning
        case .weekly:  return BrandColor.info
        case .monthly: return BrandColor.income
        case .yearly:  return BrandColor.primary
        }
    }
}
