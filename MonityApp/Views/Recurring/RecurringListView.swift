import SwiftUI

struct RecurringListView: View {
    @StateObject private var viewModel = RecurringViewModel()
    @State private var showAddRecurring = false
    @State private var editingRule: RecurringRule?
    @State private var ruleToDelete: RecurringRule?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.rules.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "arrow.triangle.2.circlepath",
                        title: "no_recurring",
                        message: "add_first_recurring"
                    )
                } else {
                    List {
                        ForEach(viewModel.rules) { rule in
                            RecurringRuleCard(rule: rule) {
                                Task { await viewModel.toggleActive(rule) }
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                editingRule = rule
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    ruleToDelete = rule
                                } label: {
                                    Label("delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    editingRule = rule
                                } label: {
                                    Label("edit", systemImage: "pencil")
                                }
                                .tint(AppTheme.accent)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("recurring_transactions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showAddRecurring = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.primaryGradient)
                            .clipShape(Circle())
                    }
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
                AddRecurringView {
                    Task { await viewModel.loadRules() }
                }
            }
            .sheet(item: $editingRule) { rule in
                AddRecurringView(editingRule: rule) {
                    Task { await viewModel.loadRules() }
                }
            }
            .refreshable { await viewModel.loadRules() }
            .task { await viewModel.loadRules() }
        }
    }
}

struct RecurringRuleCard: View {
    let rule: RecurringRule
    var onToggle: () -> Void

    var body: some View {
        SolidCard {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Text(rule.category?.icon ?? "💰")
                        .font(.title2)
                        .frame(width: 46, height: 46)
                        .background(categoryColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(rule.category?.localizedName ?? L("uncategorized"))
                            .font(.subheadline.weight(.semibold))

                        if !rule.note.isEmpty {
                            Text(rule.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formattedAmount)
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(rule.type == .income ? AppTheme.income : AppTheme.expense)

                        Text(LocalizedStringKey(rule.frequency.rawValue))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(frequencyColor)
                            .clipShape(Capsule())
                    }
                }
                .padding(16)

                Divider()

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption2)
                        Text(nextExecutionText)
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(AppTheme.accent)

                    Spacer()

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onToggle()
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(rule.isActive ? AppTheme.income : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(rule.isActive ? "active" : "paused")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(rule.isActive ? AppTheme.income : .gray)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(rule.isActive ? AppTheme.income.opacity(0.1) : Color.gray.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .opacity(rule.isActive ? 1 : 0.65)
    }

    private var formattedAmount: String {
        let prefix = rule.type == .income ? "+" : "-"
        return prefix + CurrencyHelper.format(rule.amount, currency: rule.currency)
    }

    private var categoryColor: Color {
        guard let hex = rule.category?.color else { return AppTheme.accent }
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
        case .daily: return .orange
        case .weekly: return AppTheme.accent
        case .monthly: return AppTheme.income
        case .yearly: return .purple
        }
    }
}
