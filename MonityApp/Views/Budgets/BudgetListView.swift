import SwiftUI

struct BudgetListView: View {
    @StateObject private var viewModel = BudgetViewModel()
    @State private var showAddBudget = false

    var body: some View {
        ZStack {
            CanvasBackground()

            if viewModel.budgetStatuses.isEmpty && !viewModel.isLoading {
                EmptyStateCard(
                    icon: "chart.bar.doc.horizontal",
                    title: "no_budgets",
                    message: "add_first_budget",
                    actionTitle: "add_budget",
                    action: { showAddBudget = true }
                )
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(viewModel.budgetStatuses) { budget in
                            BudgetProgressView(budget: budget)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteBudget(budget.id) }
                                    } label: {
                                        Label("delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
                }
                .refreshable { await viewModel.loadBudgets() }
            }
        }
        .navigationTitle("budgets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                FloatingPlusButton { showAddBudget = true }
            }
        }
        .sheet(isPresented: $showAddBudget) {
            AddBudgetView(categories: viewModel.categoriesWithoutBudget) {
                Task { await viewModel.loadBudgets() }
            }
        }
        .task { await viewModel.loadBudgets() }
    }
}
