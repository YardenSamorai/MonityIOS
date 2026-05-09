import SwiftUI

// MARK: - Savings goals

struct SavingsGoalsListView: View {
    @StateObject private var viewModel = GoalsViewModel()
    @State private var showAdd = false
    @State private var editing: SavingsGoal?

    var body: some View {
        ZStack {
            CanvasBackground()
            if viewModel.isLoading && viewModel.goals.isEmpty {
                ProgressView()
            } else {
                List {
                    ForEach(viewModel.goals) { goal in
                        Button {
                            editing = goal
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(goal.name)
                                    .font(AppFont.titleS)
                                ProgressView(value: min(goal.currentAmount / max(goal.targetAmount, 0.01), 1))
                                    .tint(BrandColor.primary)
                                HStack {
                                    Text(CurrencyHelper.format(goal.currentAmount, currency: goal.currency))
                                        .font(.caption.weight(.semibold))
                                    Text(L("goal_of"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(CurrencyHelper.format(goal.targetAmount, currency: goal.currency))
                                        .font(.caption.weight(.semibold))
                                    Spacer()
                                    if let d = goal.targetDate, !d.isEmpty {
                                        Text(DateHelper.display(d))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { idx in
                        Task {
                            for i in idx {
                                await viewModel.delete(viewModel.goals[i].id)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(L("savings_goals_title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddEditSavingsGoalSheet(viewModel: viewModel, existing: nil)
        }
        .sheet(item: $editing) { g in
            AddEditSavingsGoalSheet(viewModel: viewModel, existing: g)
        }
        .task { await viewModel.load() }
    }
}

private struct AddEditSavingsGoalSheet: View {
    @ObservedObject var viewModel: GoalsViewModel
    let existing: SavingsGoal?
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var targetStr = ""
    @State private var currentStr = ""
    @State private var hasDeadline = false
    @State private var deadline = Date()

    private var currency: String {
        AuthService.shared.currentUser?.preferredCurrency ?? "ILS"
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(L("goal_name_placeholder"), text: $name)
                TextField(L("goal_target_amount"), text: $targetStr)
                    .keyboardType(.decimalPad)
                TextField(L("goal_current_saved"), text: $currentStr)
                    .keyboardType(.decimalPad)
                Toggle(L("goal_has_deadline"), isOn: $hasDeadline)
                if hasDeadline {
                    DatePicker(L("goal_deadline"), selection: $deadline, displayedComponents: .date)
                }
            }
            .navigationTitle(existing == nil ? L("goal_add_title") : L("goal_edit_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("save")) {
                        Task {
                            let target = Double(targetStr.replacingOccurrences(of: ",", with: ".")) ?? 0
                            let current = Double(currentStr.replacingOccurrences(of: ",", with: ".")) ?? 0
                            let dateStr = hasDeadline ? DateHelper.toAPIString(deadline) : nil
                            if let ex = existing {
                                await viewModel.update(ex, name: name, target: target, current: current, targetDate: dateStr)
                            } else {
                                await viewModel.create(name: name, target: target, current: current, currency: currency, targetDate: dateStr)
                            }
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || targetStr.isEmpty)
                }
            }
            .onAppear {
                if let ex = existing {
                    name = ex.name
                    targetStr = String(format: "%.2f", ex.targetAmount)
                    currentStr = String(format: "%.2f", ex.currentAmount)
                    if let d = ex.targetDate, let parsed = DateHelper.fromAPIString(d) {
                        hasDeadline = true
                        deadline = parsed
                    }
                }
            }
        }
    }
}

// MARK: - Category rules

struct CategoryRulesListView: View {
    @StateObject private var viewModel = CategoryRulesViewModel()
    @State private var categories: [Category] = []
    @State private var showAdd = false

    var body: some View {
        ZStack {
            CanvasBackground()
            if viewModel.isLoading && viewModel.rules.isEmpty {
                ProgressView()
            } else {
                List {
                    Section {
                        Text("category_rules_explainer")
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.rules) { rule in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\"\(rule.pattern)\"")
                                    .font(.subheadline.weight(.semibold))
                                Text(rule.Category?.localizedName ?? "—")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(rule.priority)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { idx in
                        Task {
                            for i in idx {
                                await viewModel.delete(viewModel.rules[i].id)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(L("category_rules_title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(categories.isEmpty)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddCategoryRuleSheet(viewModel: viewModel, categories: categories)
        }
        .task {
            await viewModel.load()
            await loadCategories()
        }
    }

    private func loadCategories() async {
        do {
            let r: CategoryListResponse = try await APIClient.shared.request(endpoint: "/categories")
            categories = r.categories.filter { $0.type == .expense || $0.type == .both }
        } catch {
            categories = []
        }
    }
}

private struct AddCategoryRuleSheet: View {
    @ObservedObject var viewModel: CategoryRulesViewModel
    let categories: [Category]
    @Environment(\.dismiss) private var dismiss

    @State private var pattern = ""
    @State private var categoryId: Int?
    @State private var priority = 0

    var body: some View {
        NavigationStack {
            Form {
                TextField(L("rule_pattern_placeholder"), text: $pattern)
                Picker(L("category"), selection: $categoryId) {
                    Text("—").tag(Int?.none)
                    ForEach(categories) { c in
                        Text(c.localizedName).tag(Optional(c.id))
                    }
                }
                Stepper(value: $priority, in: 0...100) {
                    HStack {
                        Text("rule_priority_label")
                        Spacer()
                        Text("\(priority)")
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle(L("rule_add_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("save")) {
                        Task {
                            if let cid = categoryId {
                                await viewModel.create(pattern: pattern, categoryId: cid, priority: priority)
                            }
                            dismiss()
                        }
                    }
                    .disabled(pattern.trimmingCharacters(in: .whitespaces).isEmpty || categoryId == nil)
                }
            }
        }
    }
}

// MARK: - Privacy & household info

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text(L("privacy_policy_body"))
                .font(AppFont.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.screenHorizontal)
        }
        .background(CanvasBackground())
        .navigationTitle(L("privacy_policy_title"))
    }
}

struct HouseholdPermissionsInfoView: View {
    var body: some View {
        ScrollView {
            Text(L("household_permissions_body"))
                .font(AppFont.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.screenHorizontal)
        }
        .background(CanvasBackground())
        .navigationTitle(L("household_permissions_title"))
    }
}
