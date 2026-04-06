import SwiftUI

struct TransactionListView: View {
    @StateObject private var viewModel = TransactionViewModel()
    @State private var showAddTransaction = false
    @State private var editingTransaction: Transaction?
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.filteredTransactions.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "tray",
                        title: "no_transactions",
                        message: "add_first_transaction"
                    )
                } else {
                    List {
                        ForEach(Array(viewModel.filteredTransactions.enumerated()), id: \.element.id) { index, transaction in
                            TransactionRowView(transaction: transaction)
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                .listRowSeparator(.hidden)
                                .contentShape(Rectangle())
                                .staggeredAppear(appeared: appeared, index: min(index, 12))
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    editingTransaction = transaction
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        Task {
                                            withAnimation(.spring(response: 0.4)) {
                                                Task { await viewModel.deleteTransaction(transaction.id) }
                                            }
                                        }
                                    } label: {
                                        Label("delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        editingTransaction = transaction
                                    } label: {
                                        Label("edit", systemImage: "pencil")
                                    }
                                    .tint(AppTheme.accent)
                                }
                        }

                        if viewModel.currentPage < viewModel.totalPages {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(24)
                                .listRowSeparator(.hidden)
                                .onAppear {
                                    Task { await viewModel.loadTransactions(page: viewModel.currentPage + 1) }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "search_transactions")
            .navigationTitle("transactions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showAddTransaction = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.primaryGradient)
                            .clipShape(Circle())
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            viewModel.filterType = nil
                            Task { await viewModel.loadTransactions() }
                        } label: {
                            Label("all", systemImage: "list.bullet")
                        }
                        Button {
                            viewModel.filterType = .expense
                            Task { await viewModel.loadTransactions() }
                        } label: {
                            Label("expenses", systemImage: "arrow.up.right")
                        }
                        Button {
                            viewModel.filterType = .income
                            Task { await viewModel.loadTransactions() }
                        } label: {
                            Label("income", systemImage: "arrow.down.left")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.body.weight(.medium))
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView {
                    Task { await viewModel.loadTransactions() }
                }
            }
            .sheet(item: $editingTransaction) { txn in
                AddTransactionView(editingTransaction: txn) {
                    Task { await viewModel.loadTransactions() }
                }
            }
            .refreshable {
                appeared = false
                await viewModel.loadTransactions()
                appeared = true
            }
            .task {
                await viewModel.loadTransactions()
                appeared = true
            }
        }
    }
}
