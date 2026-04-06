import SwiftUI

struct BudgetListView: View {
    @StateObject private var viewModel = BudgetViewModel()
    @State private var showAddBudget = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.budgetStatuses.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "chart.bar.doc.horizontal",
                        title: "no_budgets",
                        message: "add_first_budget"
                    )
                } else {
                    List {
                        ForEach(viewModel.budgetStatuses) { budget in
                            BudgetProgressView(budget: budget)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let b = viewModel.budgetStatuses[index]
                                Task { await viewModel.deleteBudget(b.id) }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("budgets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddBudget = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddBudget) {
                AddBudgetView(categories: viewModel.categoriesWithoutBudget) {
                    Task { await viewModel.loadBudgets() }
                }
            }
            .refreshable {
                await viewModel.loadBudgets()
            }
            .task {
                await viewModel.loadBudgets()
            }
        }
    }
}
